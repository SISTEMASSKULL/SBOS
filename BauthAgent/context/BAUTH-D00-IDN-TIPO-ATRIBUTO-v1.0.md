# BAUTH D00 — Catálogo de Tipos de Atributo: `idn_tipo_atributo`
**Versión:** 1.1 · **Fecha:** 2026-07-07 · **Autor:** bauth-developer
**Propósito:** Definir el catálogo controlado de tipos de atributo de identidad.
Cada tipo es una entrada con código, validación, formato, máscara y átomo de acceso.
Analogía exacta: `cfg_policy_library` es para políticas lo que `idn_tipo_atributo` es
para los datos de identidad.

---

## 1. El problema que resuelve

### Antes (texto libre — actual idn_atributo):
```
category   = 'contacto'
attr_key   = 'telefono'      ← texto libre — nadie garantiza consistencia
attr_subtype = 'mobile'      ← texto libre — puede ser 'movil', 'cel', 'celular'
display_format = 'E164'      ← repetido en cada fila
validation_policy = JSONB    ← repetido en cada fila, puede ser diferente
atom_code  = 5814            ← repetido en cada fila
```

Problema: no hay vocabulario controlado. Dos desarrolladores pueden registrar
el mismo teléfono de dos formas distintas e incompatibles. La validación
puede diferir entre filas del mismo tipo. No hay máscaras garantizadas.

### Después (catálogo controlado — propuesta):
```
tipo_code = 2001
tipo_key  = 'telefono_movil'   ← enum controlado
tipo_nombre = 'Teléfono Móvil'
display_format = 'E164'        ← centralizado en el tipo, no en la fila
mask = '+## (###) ###-####'    ← centralizado
validation_policy = JSONB      ← centralizado
atom_code = 5814               ← centralizado
```

`idn_atributo` solo almacena: `(entidad, tipo_code, value)`.
Todo lo demás viene del catálogo. Una sola fuente de verdad.

---

## 2. Analogía con la arquitectura existente

```
cfg_policy_library    =  CATÁLOGO de ingredientes normativos
  ↕
idn_tipo_atributo     =  CATÁLOGO de tipos de atributo de identidad

cfg_tenant_config     =  instancia: el tenant ELIGIÓ estas políticas
  ↕
idn_atributo          =  instancia: la entidad TIENE este valor de este tipo

cfg_rule_evaluation   =  PDP evalúa la política en runtime
  ↕
átomo D00 (BitMask)   =  PDP evalúa si el actor puede ver/escribir este tipo
```

El patrón es idéntico. El catálogo define QUÉ existe y cómo se valida.
La tabla de instancia almacena QUÉ valor tiene cada entidad.

---

## 3. DDL propuesto — `idn_tipo_atributo`

```sql
CREATE TABLE bauth.idn_tipo_atributo (
    -- Identificación
    tipo_code        SMALLINT         NOT NULL,   -- código único estable
    categoria        TEXT             NOT NULL,   -- grupo temático
    tipo_key         TEXT             NOT NULL,   -- clave canónica snake_case
    tipo_nombre      TEXT             NOT NULL,   -- nombre en español (UI)
    tipo_nombre_en   TEXT,                        -- nombre en inglés (API)
    descripcion      TEXT,                        -- qué es y para qué sirve

    -- Formato y presentación
    display_format   TEXT,                        -- E164, EMAIL, DATE_ISO, ENUM, etc.
    mask             TEXT,                        -- patrón de visualización
    placeholder      TEXT,                        -- ejemplo en UI

    -- Validación (centralizada — no se repite en cada fila)
    validation_policy JSONB           NOT NULL DEFAULT '{}'::jsonb,
    --  {
    --    "required": false,
    --    "regex": "^\\+[1-9]\\d{7,14}$",
    --    "min_length": 7,
    --    "max_length": 16,
    --    "allowed_values": [],     ← para tipo ENUM
    --    "normalize": "E164",      ← normalización automática al guardar
    --    "unique_per_entity": false,
    --    "standard_ref": "ITU-T E.164"
    --  }

    -- Control de acceso BitMask (D00 atoms)
    -- Cada columna es un átomo diferente que controla un verbo distinto
    atom_read        SMALLINT REFERENCES bauth.privilege_atom(atom_code),
    atom_write       SMALLINT REFERENCES bauth.privilege_atom(atom_code),
    atom_verify      SMALLINT REFERENCES bauth.privilege_atom(atom_code),
    atom_export      SMALLINT REFERENCES bauth.privilege_atom(atom_code),
    -- atom_read   → quién puede VER el valor
    -- atom_write  → quién puede CREAR/EDITAR
    -- atom_verify → quién puede MARCAR COMO VERIFICADO
    -- atom_export → quién puede EXPORTAR (GDPR/privacidad)

    -- Comportamiento
    aplica_a         TEXT[]           NOT NULL DEFAULT '{}',
    -- a qué entidades aplica: '{tenant,bdomain,bsubdomain,pos,actor}'
    es_multiple      BOOLEAN          NOT NULL DEFAULT true,
    -- ¿puede haber más de uno por entidad? (ej: N teléfonos = true, NIT = false)
    es_verificable   BOOLEAN          NOT NULL DEFAULT false,
    -- ¿puede marcarse como verificado? (email, teléfono, documentos = true)
    es_sensible      BOOLEAN          NOT NULL DEFAULT false,
    -- ¿requiere auditoría especial de acceso? (NIT, CI, cuenta bancaria)
    muestra_enmascarado BOOLEAN       NOT NULL DEFAULT false,
    -- ¿roles de baja jerarquía ven solo versión enmascarada?
    -- (ej: teléfono → +591 ### ### ### en vez del número completo)

    -- Metadatos
    sort_order       SMALLINT         NOT NULL DEFAULT 0,
    is_active        BOOLEAN          NOT NULL DEFAULT true,
    standard_ref     TEXT,            -- norma de referencia (NIST, ITU-T, ISO...)
    created_at       TIMESTAMPTZ      NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_idn_tipo_atributo PRIMARY KEY (tipo_code),
    CONSTRAINT uk_idn_tipo_atributo_key UNIQUE (categoria, tipo_key),
    CONSTRAINT ck_categoria CHECK (categoria IN (
        'personal','contacto','documento','ubicacion',
        'profesional','financiero','medico','dispositivo',
        'suscripcion','facturacion','educacion','seguridad'
    ))
);

CREATE INDEX ix_idn_tipo_categoria ON bauth.idn_tipo_atributo (categoria, is_active);
CREATE INDEX ix_idn_tipo_atom ON bauth.idn_tipo_atributo (atom_read) WHERE atom_read IS NOT NULL;
```

### `idn_atributo` simplificado — referencias tipo_code

```sql
CREATE TABLE bauth.idn_atributo (
    id           UUID        NOT NULL DEFAULT gen_random_uuid(),
    entidad_tipo TEXT        NOT NULL,  -- 'tenant'|'bdomain'|'bsubdomain'|'pos'|'actor'
    entidad_id   UUID        NOT NULL,
    tipo_code    SMALLINT    NOT NULL REFERENCES bauth.idn_tipo_atributo(tipo_code),

    value_text   TEXT,                  -- para tipos simples (teléfono, email, nombre)
    value_data   JSONB,                 -- para tipos estructurados (dirección, coordenadas)

    -- Control de cardinalidad cuando es_multiple=true
    is_primary   BOOLEAN     NOT NULL DEFAULT false,
    sort_order   SMALLINT    NOT NULL DEFAULT 0,

    -- Verificación (solo si es_verificable=true en el tipo)
    is_verified  BOOLEAN     NOT NULL DEFAULT false,
    verified_at  TIMESTAMPTZ,
    verified_by  UUID,                  -- UUID del actor que verificó

    -- Auditoría
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_idn_atributo PRIMARY KEY (id),
    CONSTRAINT fk_idn_atributo_tipo FOREIGN KEY (tipo_code)
        REFERENCES bauth.idn_tipo_atributo(tipo_code),
    CONSTRAINT ck_entidad_tipo CHECK (entidad_tipo IN
        ('tenant','bdomain','bsubdomain','pos','actor')),
    CONSTRAINT ck_valor CHECK (value_text IS NOT NULL OR value_data IS NOT NULL)
);

-- Índice principal: (entidad + tipo) → búsqueda directa O(log n)
CREATE UNIQUE INDEX ix_idn_atributo_primario
    ON bauth.idn_atributo (entidad_id, tipo_code)
    WHERE is_primary = true;
    -- Solo puede haber UN primario por (entidad, tipo)

CREATE INDEX ix_idn_atributo_entidad
    ON bauth.idn_atributo (entidad_id, tipo_code, sort_order);

CREATE INDEX ix_idn_atributo_valor
    ON bauth.idn_atributo (tipo_code, value_text)
    WHERE value_text IS NOT NULL;
    -- Para búsquedas inversas: ¿quién tiene este email?

CREATE INDEX ix_idn_atributo_data
    ON bauth.idn_atributo USING GIN (value_data)
    WHERE value_data IS NOT NULL;
```

---

## 4. Catálogo completo — `idn_tipo_atributo` (seed)

### 4.1 Categoría: `personal` — Nombre y datos biográficos

| tipo_code | tipo_key | tipo_nombre | display_format | mask | aplica_a | es_multiple |
|---|---|---|---|---|---|---|
| 1001 | nombre_primero | Primer Nombre | TEXT | — | bdomain,actor | false |
| 1002 | nombre_segundo | Segundo Nombre | TEXT | — | bdomain,actor | false |
| 1003 | nombre_tercero | Tercer Nombre | TEXT | — | bdomain,actor | false |
| 1004 | apellido_paterno | Apellido Paterno | TEXT | — | bdomain,actor | false |
| 1005 | apellido_materno | Apellido Materno | TEXT | — | bdomain,actor | false |
| 1006 | apellido_casada | Apellido de Casada | TEXT | — | bdomain,actor | false |
| 1007 | apellido_compuesto | Apellido Compuesto | TEXT | — | bdomain,actor | false |
| 1008 | nombre_preferido | Nombre Preferido | TEXT | — | bdomain,actor | false |
| 1009 | nombre_legal_completo | Nombre Legal Completo | TEXT | — | bdomain,actor | false |
| 1010 | nombre_comercial | Nombre Comercial / Marca | TEXT | — | tenant,bdomain | false |
| 1011 | nombre_legal_alt | Nombre Legal en Otro País | TEXT | — | bdomain,actor | true |

**Validación tipo_code=1001 (Primer Nombre):**
```json
{
  "required": true,
  "regex": "^[A-Za-záéíóúüñÁÉÍÓÚÜÑ][A-Za-záéíóúüñÁÉÍÓÚÜÑ '\\-]+$",
  "min_length": 1,
  "max_length": 50,
  "normalize": "TRIM_UPPERCASE_FIRST",
  "standard_ref": "ISO/IEC 24760-2:2025"
}
```
- atom_read = 5811 (D00.org.bdomain.nombre)
- atom_write = 5811+verb_write (nuevo verbo WRITE)
- es_verificable = false
- es_sensible = false
- muestra_enmascarado = false

---

### 4.2 Categoría: `personal` — Datos biográficos

| tipo_code | tipo_key | tipo_nombre | display_format | allowed_values | aplica_a |
|---|---|---|---|---|---|
| 1101 | fecha_nacimiento | Fecha de Nacimiento | DATE_ISO | — | bdomain,actor |
| 1102 | genero | Género | ENUM | M,F,NB,NR,X | bdomain,actor |
| 1103 | estado_civil | Estado Civil | ENUM | soltero,casado,divorciado,viudo,union_libre,separado | bdomain,actor |
| 1104 | tipo_sangre | Tipo de Sangre | ENUM | A+,A-,B+,B-,AB+,AB-,O+,O- | actor |
| 1105 | nacionalidad | Nacionalidad | COUNTRY_CODE | → bglobal.global_country | bdomain,actor |
| 1106 | idioma_principal | Idioma Principal | LOCALE_BCP47 | → bglobal.global_language | tenant,bdomain,actor |
| 1107 | idioma_adicional | Idioma Adicional | LOCALE_BCP47 | → bglobal.global_language | bdomain,actor |
| 1108 | timezone | Zona Horaria | TIMEZONE_IANA | → bglobal.geo_timezone | tenant,bdomain,actor |
| 1109 | pais_nacimiento | País de Nacimiento | COUNTRY_CODE | → bglobal.global_country | actor |
| 1110 | lugar_nacimiento | Lugar de Nacimiento | TEXT | — | actor |
| 1111 | es_menor_edad | Es Menor de Edad | BOOLEAN | true,false | actor |
| 1112 | tutor_legal | Tutor Legal (UUID) | UUID_REF | → idn_atributo.entidad_id | actor |

**Validación tipo_code=1101 (Fecha de Nacimiento):**
```json
{
  "required": true,
  "regex": "^\\d{4}-\\d{2}-\\d{2}$",
  "past_date": true,
  "min_age_years": 0,
  "max_age_years": 150,
  "standard_ref": "ISO 8601"
}
```
- atom_read = 5822 (D00.org.actor.type — acceso a identidad de actor)
- es_sensible = true
- muestra_enmascarado = false (fecha de nacimiento no se enmascara en el modelo)

---

### 4.3 Categoría: `contacto` — Teléfonos

| tipo_code | tipo_key | tipo_nombre | display_format | mask | es_verificable |
|---|---|---|---|---|---|
| 2001 | telefono_movil | Teléfono Móvil | E164 | +## (###) ###-#### | true |
| 2002 | telefono_fijo | Teléfono Fijo | E164 | +## ## ### ### | true |
| 2003 | telefono_trabajo | Teléfono de Trabajo | E164 | +## (###) ###-#### | false |
| 2004 | telefono_emergencia | Teléfono de Emergencia | E164 | +## (###) ###-#### | false |
| 2005 | telefono_fax | Fax | E164 | +## ## ### ### | false |
| 2006 | telefono_extension | Extensión Telefónica | TEXT | ext. #### | false |
| 2007 | whatsapp | WhatsApp | E164 | +## (###) ###-#### | true |
| 2008 | telegram | Telegram (username) | TEXT | @username | false |
| 2009 | signal | Signal | E164 | +## (###) ###-#### | false |
| 2010 | viber | Viber | E164 | +## (###) ###-#### | false |

**Validación tipo_code=2001 (Teléfono Móvil):**
```json
{
  "required": false,
  "regex": "^\\+[1-9]\\d{7,14}$",
  "min_length": 8,
  "max_length": 16,
  "normalize": "E164_ITU",
  "unique_per_entity": false,
  "standard_ref": "ITU-T E.164"
}
```
- atom_read = 5814 (D00.org.bdomain.telefono)
- es_verificable = true → se puede verificar con SMS OTP
- es_sensible = false
- muestra_enmascarado = true → +591 ### ### ### (para roles de baja jerarquía)
- aplica_a = '{tenant,bdomain,bsubdomain,pos,actor}'

**Diferencias entre los tipos de teléfono:**
```
tipo_code | tipo_key              | Propósito               | Verificable | Enmascara
2001      | telefono_movil        | Contacto personal       | Sí (SMS OTP)| Sí
2002      | telefono_fijo         | Contacto en oficina     | Sí (llamada)| No
2003      | telefono_trabajo      | Contacto laboral        | No          | No
2004      | telefono_emergencia   | Solo emergencias 24h    | No          | No
2005      | telefono_fax          | Envío de documentos     | No          | No
2006      | telefono_extension    | Interno en centralita   | No          | No
2007      | whatsapp              | Mensajería WhatsApp     | Sí          | Sí
2008      | telegram              | Mensajería Telegram     | No          | No
```

---

### 4.4 Categoría: `contacto` — Emails

| tipo_code | tipo_key | tipo_nombre | display_format | es_verificable | es_sensible |
|---|---|---|---|---|---|
| 2101 | email_personal | Email Personal | EMAIL | true | false |
| 2102 | email_trabajo | Email de Trabajo | EMAIL | true | false |
| 2103 | email_billing | Email de Facturación | EMAIL | false | false |
| 2104 | email_legal | Email Legal/Judicial | EMAIL | false | false |
| 2105 | email_soporte | Email de Soporte | EMAIL | false | false |
| 2106 | email_recuperacion | Email de Recuperación | EMAIL | true | true |
| 2107 | email_rrhh | Email de RRHH | EMAIL | false | false |
| 2108 | email_prensa | Email de Prensa | EMAIL | false | false |
| 2109 | email_ventas | Email de Ventas | EMAIL | false | false |

**Validación tipo_code=2101 (Email Personal):**
```json
{
  "required": false,
  "regex": "^[a-zA-Z0-9._%+\\-]+@[a-zA-Z0-9.\\-]+\\.[a-zA-Z]{2,}$",
  "max_length": 254,
  "normalize": "LOWERCASE",
  "unique_per_entity": false,
  "standard_ref": "RFC 5321"
}
```
- atom_read = 5813 (D00.org.bdomain.email)
- es_verificable = true → se puede verificar con Email OTP/link
- email_recuperacion (2106) → es_sensible = true (auditoría extra en acceso)

---

### 4.5 Categoría: `contacto` — Redes sociales y mensajería

| tipo_code | tipo_key | tipo_nombre | display_format | mask |
|---|---|---|---|---|
| 2201 | linkedin | LinkedIn | URL | linkedin.com/in/_____ |
| 2202 | twitter_x | Twitter / X | TEXT | @handle |
| 2203 | instagram | Instagram | TEXT | @handle |
| 2204 | facebook | Facebook | URL | facebook.com/_____ |
| 2205 | github | GitHub | URL | github.com/_____ |
| 2206 | youtube | YouTube | URL | — |
| 2207 | tiktok | TikTok | TEXT | @handle |
| 2208 | sitio_web | Sitio Web | URL | https://_____ |
| 2209 | whatsapp_biz | WhatsApp Business | E164 | +## (###) ###-#### |

**Validación tipo_code=2201 (LinkedIn):**
```json
{
  "regex": "^https://www\\.linkedin\\.com/(in|company)/[A-Za-z0-9\\-]+/?$",
  "max_length": 200,
  "standard_ref": "URL formato canónico LinkedIn"
}
```

---

### 4.6 Categoría: `documento` — Identidad personal (29 países)

| tipo_code | tipo_key | tipo_nombre | display_format | mask | validation_regex |
|---|---|---|---|---|---|
| 3001 | ci_bo | CI Bolivia | ID_BO | #######-XX | `^\d{6,8}-[A-Z]{2}$` |
| 3002 | dni_ar | DNI Argentina | ID_AR | ##.###.### | `^\d{7,8}$` |
| 3003 | cpf_br | CPF Brasil (persona) | ID_BR | ###.###.###-## | `^\d{11}$` + módulo 11 |
| 3004 | rut_cl | RUT Chile | ID_CL | ##.###.###-X | algoritmo verificador |
| 3005 | curp_mx | CURP México | ID_MX | — | `^[A-Z]{4}\d{6}[HM][A-Z]{5}[A-Z0-9]\d$` |
| 3006 | dui_sv | DUI El Salvador | ID_SV | ########-# | `^\d{9}$` |
| 3007 | dni_pe | DNI Perú | ID_PE | ######## | `^\d{8}$` |
| 3008 | cc_co | Cédula Colombia | ID_CO | — | `^\d{6,10}$` |
| 3009 | cedula_ec | Cédula Ecuador | ID_EC | — | 10 dígitos + módulo 10 |
| 3010 | cedula_ve | Cédula Venezuela | ID_VE | V/E-####### | `^[VEve]-?\d{6,8}$` |
| 3011 | cedula_uy | CI Uruguay | ID_UY | #.###.###-# | dígito verificador |
| 3012 | cedula_py | CI Paraguay | ID_PY | #.###.### | `^\d{7,8}$` |
| 3013 | pasaporte | Pasaporte ICAO | PASSPORT_ICAO | XX#######X | ICAO 9303 |
| 3014 | residencia | Permiso de Residencia | TEXT | — | — |
| 3015 | visa | Visa/Visado | TEXT | — | — |
| 3016 | lic_conducir | Licencia de Conducir | TEXT | — | por país |
| 3017 | dni_es | DNI España | ID_ES | ########X | letra verificadora |
| 3018 | id_fr | Carte d'Identité Francia | ID_FR | — | — |
| 3019 | personalausweis | Personalausweis Alemania | ID_DE | — | — |
| 3020 | dni_it | CI Italia | ID_IT | — | — |
| 3021 | national_id_us | SSN USA (enmascarado) | ID_US | ###-##-#### | `^\d{3}-\d{2}-\d{4}$` |
| 3022 | nhs_uk | NHS Number Reino Unido | ID_UK | ### ### #### | 10 dígitos |
| 3023 | did_w3c | DID Decentralizado W3C | TEXT | did:method:id | W3C DID Core spec |
| 3024 | euid | EUDI Wallet (eIDAS 2.0) | TEXT | — | eIDAS 2.0 |
| 3025 | carnet_func | Carnet Funcionario Público | TEXT | — | por entidad |
| 3026 | matric_prof | Matrícula Profesional | TEXT | — | por colegio |
| 3027 | carnet_afp | Carnet AFP/Pensión | TEXT | — | por entidad |
| 3028 | carnet_seguro | Carnet Seguro Médico | TEXT | — | por entidad |

- atom_read = 5815 (D00.org.bdomain.ci) para CI/DNI
- atom_read = 5826 (D00.org.actor.id_doc_type) para actor
- es_sensible = true (todos los documentos de identidad)
- es_verificable = true (se puede verificar contra registro oficial)
- muestra_enmascarado = true (solo últimos 3 dígitos para roles sin permisos)

---

### 4.7 Categoría: `documento` — Tributario / Fiscal (24 países)

| tipo_code | tipo_key | tipo_nombre | display_format | mask | validation |
|---|---|---|---|---|---|
| 3101 | nit_bo | NIT Bolivia | TAX_BO | ######## | `^\d{7,10}$` |
| 3102 | ruc_pe | RUC Perú | TAX_PE | ########### | 11 dígitos + módulo 11 |
| 3103 | ruc_ec | RUC Ecuador | TAX_EC | ############## | 13 dígitos |
| 3104 | cnpj_br | CNPJ Brasil (empresa) | TAX_BR | ##.###.###/####-## | 14 dígitos + módulo 11 |
| 3105 | cpf_br_trib | CPF Brasil (persona tribut.) | TAX_BR_P | ###.###.###-## | mismo que ID |
| 3106 | cuit_ar | CUIT/CUIL Argentina | TAX_AR | ##-########-# | dígito verificador |
| 3107 | rfc_mx | RFC México | TAX_MX | AAAA######XXX | 12-13 chars |
| 3108 | vat_eu | VAT Unión Europea | TAX_EU | XX########## | por país |
| 3109 | ein_us | EIN USA (employer) | TAX_US | ##-####### | `^\d{2}-\d{7}$` |
| 3110 | nif_es | NIF España | TAX_ES | ########X | letra verificadora |
| 3111 | siret_fr | SIRET Francia | TAX_FR | ############### | 14 dígitos |
| 3112 | ust_de | USt-IdNr Alemania | TAX_DE | DE########### | `^DE\d{9}$` |
| 3113 | p_iva_it | Partita IVA Italia | TAX_IT | IT########### | 11 dígitos |
| 3114 | kvk_nl | KvK Países Bajos | TAX_NL | ######## | 8 dígitos |
| 3115 | cnpj_lite | Identificador fiscal genérico | TAX_GENERICO | — | — |
| 3116 | rut_cl_trib | RUT Chile (tributario) | TAX_CL | ##.###.###-X | mismo que ID |
| 3117 | nit_co | NIT Colombia | TAX_CO | #########-# | dígito verificador |
| 3118 | rif_ve | RIF Venezuela | TAX_VE | J/G/V/E-####### | — |
| 3119 | ruc_py | RUC Paraguay | TAX_PY | #######-# | — |
| 3120 | rut_uy | RUT Uruguay | TAX_UY | ########-# | — |

- atom_read = 5812 (D00.org.bdomain.nit)
- es_sensible = true (dato tributario privado)
- es_verificable = true (verificable contra SIN/SUNAT/AFIP/etc.)

---

### 4.8 Categoría: `ubicacion` — Direcciones

Las direcciones usan `value_data JSONB` porque son estructuras compuestas.
El tipo define PARA QUÉ sirve la dirección. La estructura interna es estándar.

| tipo_code | tipo_key | tipo_nombre | display_format | required_fields |
|---|---|---|---|---|
| 4001 | dir_fiscal | Dirección Fiscal | DIRECCION | calle, ciudad, pais_code |
| 4002 | dir_operativa | Dirección Operativa | DIRECCION | calle, ciudad, pais_code |
| 4003 | dir_entrega | Dirección de Entrega | DIRECCION | calle, ciudad, pais_code, referencia |
| 4004 | dir_personal | Dirección Personal (home) | DIRECCION | calle, ciudad, pais_code |
| 4005 | dir_correspon | Dirección de Correspondencia | DIRECCION | calle, ciudad, pais_code |
| 4006 | dir_judicial | Domicilio Judicial | DIRECCION | calle, ciudad, pais_code |
| 4007 | casilla_postal | Casilla Postal / P.O. Box | TEXT | — |
| 4008 | coords_gps | Coordenadas GPS | COORD_DD | — |
| 4009 | coords_utm | Coordenadas UTM | COORD_UTM | — |
| 4010 | plus_code | Plus Code (Google) | PLUS_CODE | — |
| 4011 | what3words | What3Words | TEXT | 3 palabras exactas |

**Estructura `value_data` para tipos DIRECCION (4001-4006):**
```json
{
  "calle":         "Av. Arce",
  "numero":        "2345",
  "piso":          "3",
  "depto":         "302",
  "barrio":        "Sopocachi",
  "ciudad":        "La Paz",
  "departamento":  "La Paz",
  "pais_code":     "BO",
  "codigo_postal": "10130",
  "referencia":    "Entre 20 de Octubre y Ecuador, frente al parque"
}
```

**Validación tipo_code=4001 (Dirección Fiscal):**
```json
{
  "required_keys": ["calle", "ciudad", "pais_code"],
  "optional_keys": ["numero","piso","depto","barrio","departamento","codigo_postal","referencia"],
  "pais_code_enum": "→ bglobal.global_country.iso_alpha2",
  "max_calle_len": 200,
  "max_ciudad_len": 100,
  "standard_ref": "ISO 19160-1:2015 Addressing"
}
```

- atom_read = 5816 (D00.org.bdomain.direccion)
- es_sensible = true (dirección privada)
- muestra_enmascarado = true (solo ciudad + país para roles sin permisos completos)

---

### 4.9 Categoría: `profesional` — Datos laborales y académicos

| tipo_code | tipo_key | tipo_nombre | display_format | aplica_a | es_multiple |
|---|---|---|---|---|---|
| 6001 | codigo_empleado | Código de Empleado | TEXT | actor | false |
| 6002 | cargo | Cargo / Puesto de Trabajo | TEXT | actor | false |
| 6003 | nivel_salarial | Nivel Salarial | TEXT | actor | false |
| 6004 | tipo_contrato | Tipo de Contrato | ENUM | actor | false |
| 6005 | fecha_ingreso | Fecha de Ingreso | DATE_ISO | actor | false |
| 6006 | fecha_egreso | Fecha de Egreso | DATE_ISO | actor | false |
| 6007 | titulo_academico | Título Académico | TEXT | bdomain,actor | true |
| 6008 | institucion_titulo | Institución del Título | TEXT | actor | true |
| 6009 | anio_titulacion | Año de Titulación | INTEGER | actor | true |
| 6010 | num_matricula_prof | N° de Matrícula Profesional | TEXT | actor | true |
| 6011 | colegio_profesional | Colegio Profesional | TEXT | actor | true |
| 6012 | certificacion | Certificación | TEXT | bdomain,actor | true |
| 6013 | certificacion_vence | Vencimiento Certificación | DATE_ISO | actor | true |
| 6014 | especialidad | Especialidad | TEXT | actor | true |
| 6015 | subespecialidad | Subespecialidad | TEXT | actor | true |
| 6016 | num_empleados | Número de Empleados | INTEGER | bdomain | false |
| 6017 | sector_caeb | Sector CAEB SIN | TEXT | bdomain | false |
| 6018 | giro_comercial | Giro / Actividad Comercial | TEXT | bdomain | false |
| 6019 | horario | Horario de Atención | TEXT | bdomain,bsubdomain | true |
| 6020 | metodo_pago | Método de Pago Aceptado | ENUM | bdomain,bsubdomain | true |
| 6021 | turno | Turno de Trabajo | TEXT | actor | true |
| 6022 | orcid | ORCID Investigador | TEXT | actor | false |
| 6023 | publicacion | Publicación (DOI) | TEXT | actor | true |
| 6024 | evaluacion | Evaluación de Desempeño | TEXT | actor | true |
| 6025 | habilidad | Habilidad / Skill | TEXT | actor | true |
| 6026 | idioma_prof | Idioma (nivel profesional) | LOCALE_BCP47 | actor | true |
| 6027 | acceso_temporal | Acceso Temporal (inicio/fin) | DATETIME_RANGE | actor | true |

**Validación tipo_code=6004 (Tipo de Contrato) — tipo ENUM:**
```json
{
  "allowed_values": ["indefinido","plazo_fijo","eventual","honorarios",
                     "pasantia","voluntario","socio","propietario","otro"],
  "required": false,
  "standard_ref": "Ley General del Trabajo Bolivia · SCIM 2.0 Enterprise User"
}
```

---

### 4.10 Categoría: `financiero` — Datos bancarios y económicos

| tipo_code | tipo_key | tipo_nombre | display_format | es_sensible |
|---|---|---|---|---|
| 7001 | cuenta_bancaria | Número de Cuenta Bancaria | TEXT | true |
| 7002 | banco | Entidad Bancaria | TEXT | false |
| 7003 | moneda_cuenta | Moneda de la Cuenta | ISO_4217 | false |
| 7004 | tipo_seguro_med | Tipo de Seguro Médico | ENUM | false |
| 7005 | num_seguro_med | N° Seguro Médico | TEXT | true |
| 7006 | linea_credito | Línea de Crédito | MONEY | true |
| 7007 | capital_declarado | Capital Declarado | MONEY | true |
| 7008 | avaluo | Avalúo de Bien | MONEY | true |
| 7009 | folio_real | Folio Real (DDRR) | TEXT | false |
| 7010 | num_poliza | N° Póliza de Seguro | TEXT | false |
| 7011 | scoring | Score Crediticio | INTEGER | true |

- atom_read = nuevo átomo D00 para datos financieros (GAP en átomos actuales)
- es_sensible = true para cuentas, montos y scores

---

### 4.11 Categoría: `dispositivo` — Atributos técnicos

| tipo_code | tipo_key | tipo_nombre | display_format | aplica_a |
|---|---|---|---|---|
| 8001 | modelo | Modelo del Dispositivo | TEXT | pos,actor |
| 8002 | serial | Número de Serie | TEXT | pos,actor |
| 8003 | firmware | Versión Firmware | SEMVER | pos,actor |
| 8004 | mac_address | Dirección MAC | MAC_ADDR | pos,actor |
| 8005 | ip_address | Dirección IP | IP_ADDR | pos,actor |
| 8006 | protocolo | Protocolo de Comunicación | TEXT | pos,actor |
| 8007 | cert_tls | Certificado TLS/mTLS (SHA256) | TEXT | pos,actor |
| 8008 | client_id | Client ID OAuth2 | TEXT | actor |
| 8009 | scopes | Scopes OAuth2 | TEXT | actor |
| 8010 | so_version | Sistema Operativo + Versión | TEXT | pos |
| 8011 | pci_compliant | Cumplimiento PCI DSS | BOOLEAN | pos |
| 8012 | idp_externo | IdP Externo (Federado) | TEXT | actor |
| 8013 | idp_subject | Subject del IdP Externo | TEXT | actor |
| 8014 | modelo_ia | Modelo de IA | TEXT | actor |
| 8015 | proveedor_ia | Proveedor de IA | TEXT | actor |
| 8016 | session_ia | Session ID del Agente IA | TEXT | actor |
| 8017 | supervision_ia | Nivel de Supervisión IA | ENUM | actor |

**Validación tipo_code=8004 (Dirección MAC):**
```json
{
  "regex": "^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$",
  "normalize": "UPPERCASE_COLON",
  "unique_per_entity": false,
  "standard_ref": "IEEE 802"
}
```

---

### 4.12 Categoría: `suscripcion` — Plan y límites del tenant

| tipo_code | tipo_key | tipo_nombre | display_format | aplica_a |
|---|---|---|---|---|
| 10001 | plan | Plan de Suscripción | ENUM | tenant |
| 10002 | max_bdomains | Máximo bDomains | INTEGER | tenant |
| 10003 | max_usuarios | Máximo Usuarios | INTEGER | tenant |
| 10004 | fecha_inicio | Inicio de Suscripción | DATE_ISO | tenant |
| 10005 | fecha_vencimiento | Vencimiento | DATE_ISO | tenant |
| 10006 | nivel_soporte | Nivel de Soporte | ENUM | tenant |

---

### 4.13 Categoría: `facturacion` — Identidad fiscal y modalidad

| tipo_code | tipo_key | tipo_nombre | display_format | aplica_a |
|---|---|---|---|---|
| 11001 | modalidad | Modalidad de Facturación | ENUM | tenant,bdomain |
| 11002 | nit_facturador | NIT del Facturador | TAX_BO | tenant,bdomain |
| 11003 | autorizacion_sfv | Autorización SFV (SIN) | TEXT | bdomain |
| 11004 | regimen | Régimen Tributario | ENUM | tenant,bdomain |
| 11005 | moneda | Moneda de Facturación | ISO_4217 | tenant,bdomain |
| 11006 | resolucion | Resolución Normativa SIN | TEXT | bdomain |

**Validación tipo_code=11001 (Modalidad de Facturación) — ENUM:**
```json
{
  "allowed_values": ["propio","tercero","holding_centralizado","exento","no_aplica"],
  "required": true,
  "default": "no_aplica"
}
```

---

## 5. Verbos de control BitMask por tipo

### Verbo structure — dos niveles

```
Nivel 1 (ya existe en D00): CATEGORÍA del dato
  atom 5812 = D00.org.bdomain.nit      → controla acceso a todos los datos tributarios
  atom 5813 = D00.org.bdomain.email    → controla acceso a todos los emails
  atom 5814 = D00.org.bdomain.telefono → controla acceso a todos los teléfonos
  atom 5815 = D00.org.bdomain.ci       → controla acceso a todos los documentos ID
  atom 5816 = D00.org.bdomain.direccion→ controla acceso a todas las direcciones

Nivel 2 (nuevo — verbos de acción en el tipo):
  atom_read   → quién puede LEER el valor (ya existente en Nivel 1)
  atom_write  → quién puede CREAR/EDITAR valores de este tipo
  atom_verify → quién puede MARCAR COMO VERIFICADO
  atom_export → quién puede EXPORTAR para portabilidad de datos (GDPR)
```

### Mapping tipo → verbos

```
tipo_code | atom_read | atom_write | atom_verify | atom_export | muestra_mask
2001 (telefono_movil)   | 5814 | 5814+W | 5814+V | 5814+E | true
2007 (whatsapp)         | 5814 | 5814+W | 5814+V | 5814+E | true
2101 (email_personal)   | 5813 | 5813+W | 5813+V | 5813+E | false
2106 (email_recupera)   | 5813 | 5813+W | 5813+V | 5813+E | true (sensible)
3001 (ci_bo)            | 5815 | 5815+W | 5815+V | 5815+E | true
3101 (nit_bo)           | 5812 | 5812+W | 5812+V | 5812+E | false
4001 (dir_fiscal)       | 5816 | 5816+W | null   | 5816+E | true (solo ciudad)
1001 (nombre_primero)   | 5811 | 5811+W | null   | 5811+E | false
```

**Nota sobre los verbos WRITE/VERIFY/EXPORT:**
Los átomos `5814+W`, `5814+V`, `5814+E` son NUEVOS átomos D00 que deben agregarse
al catálogo de átomos. Son las siguientes posiciones disponibles en D00 (desde 5829 en adelante).
Esto es una GAP que requiere HITL para ampliar los 20 átomos D00 actuales.

---

## 6. Ventajas del modelo tipo_code vs texto libre

| Criterio | Texto libre (anterior) | Tipo code (propuesto) |
|---|---|---|
| Vocabulario controlado | No — "mobile"/"movil"/"cel" son distintos | Sí — tipo_code=2001 es siempre el mismo |
| Validación centralizada | No — repetida en cada fila | Sí — en el catálogo |
| Formato y máscara | Repetido en cada fila | En el catálogo |
| Acceso por BitMask | atom_code por fila | atom_code en el tipo |
| Migrar nueva validación | ALTER TABLE en millones de filas | UPDATE en el catálogo |
| UI dinámica | Interpreta texto libre | Renderiza por tipo_code |
| Consulta inversa "¿quién tiene X?" | INDEX solo en value_text | INDEX en (tipo_code, value_text) |
| Internacionalización | Fijo en español | tipo_nombre_en para API en inglés |

---

## 7. Resumen ejecutivo — Relación entre capas

```
idn_tipo_atributo (catálogo seed — 200+ tipos)
  tipo_code = 2001
  tipo_key  = 'telefono_movil'
  display_format = 'E164'
  mask = '+## (###) ###-####'
  validation_policy = {regex: "^\\+...", normalize: "E164_ITU"}
  atom_read  = 5814   ← BitMask acceso READ
  atom_write = 5829   ← BitMask acceso WRITE (nuevo átomo)
  es_verificable = true
  muestra_enmascarado = true
       │
       │ referenciado por
       ▼
idn_atributo (instancias — millones de filas)
  entidad_tipo = 'actor'
  entidad_id   = UUID-Juan-López
  tipo_code    = 2001   ← FK al catálogo
  value_text   = '+59175000001'
  is_primary   = true
  is_verified  = false
```

El valor ocupa 1 fila de 4 columnas.
Todo lo demás (cómo validarlo, mostrarlo, controlarlo) está en el catálogo.

---

---

## 8. Prueba de cobertura — Todos los actores de la industria

Verificación de que el catálogo cubre los atributos de TODOS los actores conocidos.
Si algo no cabe → gap identificado → tipo_code propuesto.

---

### 8.1 HUMAN — Personas

**Empleado estándar:** 100% cubierto con categorías personal, contacto, documento, profesional, financiero, ubicacion.

**Profesional médico:** Cubre 95%. Faltan:
```
9010 matricula_medica       (medico)   → N° matrícula colegio médico regional + vigencia
9011 area_medica_habilitada (medico)   → UCI, Cirugía, Pediatría, etc. — habilitaciones
```

**Menor de edad:** Cubre el dato base. Faltan:
```
6028 grado_escolar          (educacion) → "5to Primaria", "3ro Secundaria"
6029 institucion_educativa  (educacion) → Nombre del colegio actual
9013 consentimiento_tutor   (seguridad) → ¿Tutor otorgó consentimiento? + fecha + UUID tutor
```

**Extranjero / Migrante:** Cubre pasaporte y visa. Faltan:
```
1113 pais_residencia        (personal)  → País donde reside actualmente
3030 fecha_vencimiento_doc  (documento) → Aplica a: visa, pasaporte, CI con vencimiento, permiso
```

**Visitante / Acceso temporal:** Cubre acceso_temporal (inicio/fin). Faltan:
```
6030 empresa_empleadora     (profesional) → "DHL Bolivia" — empresa que envía al visitante
6031 motivo_visita          (profesional) → entrega, mantenimiento, auditoría, inspección
6032 vehiculo_placa_visita  (profesional) → placa del vehículo con que llegó
9014 zona_acceso_permitida  (seguridad)   → áreas del edificio a las que puede acceder
```

---

### 8.2 DEVICE — Equipos y hardware (mayor brecha del catálogo)

Los tipos 8001-8017 son genéricos y no alcanzan para las propiedades técnicas específicas
de cada subcategoría de dispositivo. Se propone expandir con rangos reservados:

#### Lector biométrico — huella dactilar, iris, cara, vena de palma

```
8100 tipo_biometrico      ENUM  huella_dactilar,iris,cara,vena_palma,vena_dedo,
                                geometria_mano,multimodal
8101 far_rate             TEXT  "0.00001%"  (False Accept Rate · ISO/IEC 19795)
8102 frr_rate             TEXT  "0.1%"      (False Rejection Rate)
8103 sar_rate             TEXT  "0.0001%"   (Spoofing Accept Rate — anti-suplantación)
8104 resolucion_sensor    TEXT  "500 DPI" (huella) · "480x640px" (iris)
8105 capacidad_templates  INT   plantillas biométricas almacenables localmente
8106 modo_operacion       ENUM  verificacion_1a1, identificacion_1aN, dual_modo
8107 certif_fido2         TEXT  "FIDO2 Level 2"
8108 nivel_pad            ENUM  ISO_30107_Nivel1,2,3  (Presentation Attack Detection)
8109 tiempo_respuesta_ms  INT   ms promedio de verificación
8110 temperatura_operacion TEXT "-10°C a +50°C"
8111 grado_proteccion_ip  TEXT  "IP65" / "IP67" / "IP68"
8112 tipo_conector        ENUM  TCP_IP,RS485,Wiegand,OSDP,USB,BLE,NFC
8113 distancia_captura_cm INT   rango de captura en cm
8114 iluminacion_nir      BOOL  usa Near InfraRed
8115 angulo_vision_grados INT   campo de visión (para cámaras biométricas)
8116 distancia_deteccion_m TEXT "0.3-5m"
8117 faces_simultaneas    INT   rostros procesados en paralelo
8118 certif_gdpr_bio      TEXT  certificación GDPR para biometría facial
8119 liveness_detection   ENUM  basico,avanzado,ISO_30107_3D
```

#### Lector RFID / NFC / control de acceso

```
8120 tipo_tarjeta         ENUM  RFID_125kHz,RFID_13_56MHz,NFC,ISO14443A,
                                ISO14443B,ISO15693,DESFire,MIFARE
8121 frecuencia_rfid      ENUM  LF_125kHz,HF_13_56MHz,UHF_868MHz,UHF_902MHz
8122 formato_wiegand      ENUM  W26,W34,W37,ABA_Track2,sin_wiegand
8123 protocolo_acceso     ENUM  OSDP_v1,OSDP_v2,Wiegand,Clock_Data,RS485,TCP_IP
8124 rango_lectura_cm     INT   distancia máxima de lectura
8125 cifrado_tarjeta      BOOL  ¿cifra comunicación con la tarjeta?
```

#### Teclado PIN / keypad

```
8126 tipo_keypad          ENUM  fisico,tactil,virtual_screen
8127 longitud_pin         TEXT  "4-8 dígitos"
8128 anti_espionaje       BOOL  protector visual + scramble de teclas
8129 intentos_max_pin     INT   bloqueo tras N intentos fallidos
8130 certif_pci_pin       TEXT  "PCI PTS 5.0 SRED"  (standard_ref: PCI PTS)
```

#### Cerradura electrónica

```
8131 tipo_cerradura       ENUM  electromagnetica,electromecanica,solenoide,motorizada
8132 fuerza_retension_kg  INT   kg de retención (cerraduras magnéticas)
8133 modos_apertura       ENUM  rfid,pin,app_bt,app_wifi,llave,biometrico
8134 tiempo_apertura_seg  FLOAT segundos que permanece abierta
8135 log_local_eventos    INT   eventos almacenados localmente
8136 bateria_backup_h     INT   horas de respaldo con batería
8137 failsafe_modo        ENUM  fail_secure,fail_safe  (standard_ref: UL 294)
```

#### IoT / Sensores

```
8140 tipo_sensor          ENUM  temperatura,humedad,presion,movimiento_pir,
                                gas_co2,gas_co,gas_lpg,humo,vibracion,
                                sonido_db,luz_lux,lluvia,viento,nivel_liquido,
                                caudal,energia_kwh,corriente_amp,voltaje_v,ph
8141 rango_medicion       TEXT  "-40°C a +85°C"
8142 precision_medicion   TEXT  "±0.5°C"
8143 unidad_medicion      TEXT  "°C" / "%" / "ppm" / "kWh"
8144 intervalo_muestreo_s INT   segundos entre lecturas
8145 protocolo_iot        ENUM  MQTT,CoAP,AMQP,HTTP_REST,Modbus_TCP,Modbus_RTU,
                                OPC_UA,PROFINET,EtherCAT,BACnet,KNX,Zigbee,
                                Z_Wave,LoRaWAN,NB_IoT,LTE_M,Bluetooth_LE,
                                DLMS_COSEM,IEC_62056,ANSI_C12,PRIME,G3_PLC
8146 qos_iot              ENUM  QoS_0,QoS_1,QoS_2
8147 alimentacion         ENUM  red_220v,bateria,solar,poe,rs485_loop
8148 vida_bateria_meses   INT   meses de vida estimada con batería
```

#### PLC / Controladores industriales

```
8150 tipo_controlador     ENUM  PLC,DCS,SCADA,RTU,PAC,IPC,SIS
8151 entradas_digitales   INT
8152 salidas_digitales    INT
8153 entradas_analogicas  INT
8154 salidas_analogicas   INT
8155 ciclo_scan_ms        INT   tiempo de ciclo en ms
8156 protocolo_industrial ENUM  Profinet,Profibus,EtherCAT,Modbus_RTU,Modbus_TCP,
                                CANopen,DeviceNet,OPC_UA,DNP3,IEC_60870
8157 certif_iec62443      TEXT  "IEC 62443-3-3 SL2"  (ciberseguridad industrial)
8158 redundancia          ENUM  ninguna,caliente,fria,triple
8159 sil_nivel            ENUM  SIL0,SIL1,SIL2,SIL3,SIL4  (IEC 61508)
```

#### Robots / AGV

```
8160 tipo_robot           ENUM  articulado,scara,delta,cartesiano,cobot,movil_amr,agv
8161 num_ejes             INT
8162 carga_max_kg         FLOAT
8163 alcance_mm           INT
8164 precision_mm         FLOAT repetibilidad ±mm
8165 modo_colaborativo    BOOL  ¿opera junto a humanos sin jaula? (cobot)
8166 certif_iso10218      TEXT  "ISO 10218-1:2011"  (robots industriales seguros)
```

#### Dispositivos médicos

```
8170 tipo_dispositivo_med ENUM  monitor_signos,ventilador,bomba_infusion,
                                desfibrilador,ecg,oximetro,glucometro,
                                analizador_lab,scanner_imagen,radiologia,
                                dispensador_medicamentos
8171 clase_regulatoria    ENUM  Clase_I,Clase_II,Clase_III  (FDA/INVIMA/ANMAT)
8172 udi                  TEXT  Unique Device Identifier  (standard_ref: FDA UDI)
8173 num_registro_san     TEXT  registro ante autoridad sanitaria nacional
8174 iso13485             TEXT  "ISO 13485:2016"  (calidad dispositivos médicos)
8175 protocolo_medico     ENUM  HL7_v2,HL7_FHIR_R5,DICOM,IHE_ITI,IEEE_11073
8176 alarma_critica       BOOL  ¿genera alarmas de seguridad de vida?
8177 vida_util_anos       INT   vida útil certificada
```

#### ATM — Cajero automático

```
8180 tipo_atm             ENUM  dispensador,reciclador,deposito_cheques,multifuncion
8181 capacidad_cassettes  INT   número de cassettes de efectivo
8182 billetes_cassette    INT   capacidad por cassette
8183 denominaciones       TEXT  "20,50,100,200 BOB"
8184 certif_pci_pts       TEXT  "PCI PTS 6.0 HSM"  (standard_ref: PCI PTS)
8185 certif_pci_p2pe      TEXT  "PCI P2PE v3.0"
8186 modulos_opcionales   ENUM  lector_tarjeta,deposito_efectivo,deposito_cheque,
                                biometrico_huella,camara_frontal
8187 nivel_xfs            TEXT  "Level 3"  (CEN/XFS interoperabilidad)
8188 conectividad_atm     ENUM  ethernet,wifi,4g_lte,fibra
```

#### Terminal POS

```
8190 tipo_pos             ENUM  pos_fijo,pos_movil,softpos_smartphone,pinpad_externo
8191 certif_pci_pos       TEXT  "PCI PTS 5.0 SRED POI"
8192 protocolos_pago      ENUM  EMV_contacto,EMV_sin_contacto,NFC_QR,magstripe
8193 esquemas_pago        ENUM  visa,mastercard,amex,unionpay,qr_simple,billetera_virtual
8194 impresora_ticket     BOOL
8195 conectividad_pos     ENUM  ethernet,wifi,4g_lte,bluetooth,usb
```

#### Cámara IP / CCTV

```
8200 tipo_camara          ENUM  domo,bala,ptz,fisheye,termica,conteo,lpr,facial
8201 resolucion_video     ENUM  SD,HD_720p,FHD_1080p,4K_UHD,8MP,12MP
8202 vision_nocturna_m    INT   alcance infrarrojo en metros
8203 fps                  INT   frames por segundo
8204 angulo_vision_h      INT   grados campo visual horizontal
8205 almacen_local        TEXT  "SD 256GB" / "sin almacenamiento"
8206 analitica_ia         ENUM  movimiento,personas,vehiculos,facial,
                                conteo,incendio,lpr
8207 protocolo_video      ENUM  ONVIF_S,RTSP,H264,H265,MJPEG
```

#### Smart meter / Medidor inteligente

```
8210 tipo_medidor         ENUM  electrico_mono,electrico_tri,gas,agua_fria,
                                agua_caliente,calorimetro,solar_produccion
8211 clase_precision      TEXT  "Clase 0.5" / "Clase 1"  (IEC 62053)
8212 comunicacion_amr     ENUM  ninguna,PLC_nb,GPRS,NB_IoT,LoRaWAN,Zigbee_HAN
8213 corte_remoto         BOOL  ¿puede cortar el servicio remotamente?
```

#### Equipos de red

```
8220 tipo_equipo_red      ENUM  router,switch_l2,switch_l3,firewall,utm,
                                ids_ips,load_balancer,waf,proxy,ap_wifi,
                                controlador_wifi,servidor_radius,hsm
8221 num_interfaces       INT
8222 throughput_gbps      FLOAT
8223 vlans_activas        INT
8224 ha_modo              ENUM  standalone,activo_pasivo,activo_activo,cluster
8225 certif_common_crit   TEXT  "CC EAL4+"  (ISO/IEC 15408)
```

#### HSM — Hardware Security Module

```
8230 tipo_hsm             ENUM  network_hsm,pcie_hsm,usb_token,smart_card
8231 fips_nivel           ENUM  FIPS_140_2_L2,FIPS_140_2_L3,FIPS_140_3_L3,FIPS_140_3_L4
8232 algoritmos           TEXT  "RSA_4096,ECC_P256,Ed25519,AES_256,SHA512"
8233 capacidad_claves     INT   número de claves almacenables
8234 tps_crypto           INT   transacciones criptográficas por segundo
8235 certif_pci_hsm       TEXT  "PCI HSM v3.0"
```

---

### 8.3 Nueva categoría: `vehiculo` (9100-9119)

Vehículos, drones, AGV y maquinaria con identidad propia registrada como DEVICE.

```
9100 placa_vehiculo        TEXT     "ABC-1234" / "CB-3456-BCD"
9101 vin                   TEXT     17 chars  (standard_ref: ISO 3779)
9102 tipo_vehiculo         ENUM     auto,camioneta,camion,bus,moto,bicicleta_elec,
                                    dron_uav,agv,amr,tractor,maquinaria_pesada
9103 marca_modelo          TEXT     "Mercedes-Benz Sprinter 316 CDI"
9104 anio_fabricacion      INT      YYYY
9105 color                 TEXT
9106 capacidad_carga_kg    FLOAT
9107 gps_tracking          BOOL     ¿tiene GPS con reporting?
9108 soat_vencimiento      DATE_ISO vencimiento seguro obligatorio
9109 revision_tecnica      DATE_ISO vencimiento revisión técnica
9110 norma_emisiones       TEXT     "Euro 6 / Tier 4"

Drones / UAV adicional:
9111 masa_max_kg           FLOAT    MTOW (Max Takeoff Weight)
9112 autonomia_min         INT      minutos de vuelo
9113 certif_aeronaveg      TEXT     "AASANA-Bolivia / FAA Part 107 / EASA A1"
9114 bvlos_autorizado      BOOL     Beyond Visual Line of Sight
```

---

### 8.4 Nueva categoría: `software` (9200-9285)

Para actores tipo SERVICE, BOT y AI_AGENT.

```
SERVICE / daemon:
9200 version_sw            TEXT     SEMVER → "1.2.3"
9201 hash_binario          TEXT     SHA256 del binario (inmutabilidad)
9202 socket_path           TEXT     "/run/bos/bauth.sock"
9203 puerto_proceso        INT      TCP port o 0 si unix socket
9204 sbom                  TEXT     URL/hash Software Bill of Materials (SPDX 2.3)
9205 cve_scan_fecha        DATE_ISO fecha último escaneo de vulnerabilidades
9206 cve_score_max         FLOAT    score CVSS v3.1 máximo sin parchear

API Gateway / proxies:
9210 tipo_gateway          ENUM     api_gateway,service_mesh,reverse_proxy,cdn_edge,waf
9211 rutas_configuradas    INT
9212 plugins_activos       TEXT     "rate_limiting,jwt,mtls,oidc"
9213 rps_max               INT      requests por segundo máximos

Message Broker:
9220 tipo_broker           ENUM     kafka,rabbitmq,redis_streams,nats,mqtt_broker,
                                    activemq,pulsar
9221 num_topics            INT
9222 retencion_dias        INT
9223 replicacion_factor    INT
9224 autenticacion_sasl    ENUM     ninguna,PLAIN,SCRAM_SHA256,SCRAM_SHA512,OAUTHBEARER

BOT / procesos automatizados:
9230 tipo_bot              ENUM     cron_job,rpa_bot,etl_pipeline,report_generator,
                                    web_scraper,notification_sender,data_sync
9231 schedule_cron         TEXT     "0 2 * * *"
9232 tiempo_ejecucion_s    INT      promedio en segundos
9233 propietario_funcional UUID     UUID del HUMAN responsable
9234 plataforma_rpa        ENUM     uipath,automation_anywhere,blueprism,power_automate
9235 sistema_objetivo      TEXT     sistema que automatiza
9236 credenciales_vault    TEXT     ruta en Vault (jamás en plano)

FEDERATED — identidad externa:
9240 idp_tipo              ENUM     oidc,saml2,ldap,active_directory,cas,
                                    eidas_wallet,social_google,social_microsoft,
                                    social_apple,social_github,custom_saml
9241 idp_email_verified    BOOL     ¿el IdP confirmó el email?
9242 idp_acr               TEXT     nivel de aseguramiento del IdP externo
9243 idp_amr               TEXT     "pwd mfa" — métodos usados en el IdP
9250 eidas_level           ENUM     low,substantial,high  (eIDAS Art. 8)
9251 eidas_pid_hash        TEXT     hash del Person Identification Data credential
9252 ldap_dn               TEXT     "CN=John,OU=Users,DC=contoso,DC=com"
9253 ldap_sid              TEXT     Security Identifier del AD (inmutable)

AI_AGENT — agentes y modelos IA:
9270 version_modelo_ia     TEXT     "claude-sonnet-4-6-20250514"
9271 contexto_max_tokens   INT      200000
9272 tool_access           TEXT     "Read,Write,Edit,Bash"
9273 project_scope         TEXT     "SBOS/BauthAgent"
9274 aprobacion_hitl       ENUM     nunca,para_destructivos,siempre
9280 tipo_modelo_ml        ENUM     clasificacion,regresion,anomalias,nlp,
                                    vision,recomendacion,serie_temporal,llm
9281 framework_ml          ENUM     tensorflow,pytorch,sklearn,xgboost,onnx
9282 precision_modelo      FLOAT    accuracy / F1 en producción
9283 drift_monitor         BOOL
9284 latencia_p99_ms       INT
```

---

### 8.5 Resumen de cobertura por actor.tipo — y por qué el 100% es inalcanzable

#### Tabla de cobertura honesta

| actor.tipo | Categorías activas | Cobertura alcanzable | Tipos formalizados | Tipos aún sin formalizar |
|---|---|---|---|---|
| HUMAN | personal, contacto, documento, ubicacion, profesional, financiero, medico, educacion, seguridad, suscripcion, facturacion | ~97% | 9 tipos nuevos (§8.1) | Regulaciones futuras GDPR/Ley 164 |
| DEVICE biométrico | dispositivo 8100-8119 | ~90% | 20 tipos | Modalidades biométricas emergentes (vena retina, olor) |
| DEVICE acceso | dispositivo 8120-8137 | ~85% | 18 tipos | Protocolos propietarios de fabricante |
| DEVICE IoT/sensor | dispositivo 8140-8148 | ~70% | 9 tipos | Miles de tipos de sensor industriales sin estándar |
| DEVICE industrial | dispositivo 8150-8166 | ~60% | 17 tipos | Atributos específicos de fabricante (Siemens, Allen-Bradley) |
| DEVICE médico | dispositivo 8170-8177 | ~75% | 8 tipos | Clases FDA III + regulaciones país a país |
| DEVICE ATM/POS | dispositivo 8180-8195 | ~85% | 16 tipos | Variantes regionales (EMV Contactless LATAM) |
| DEVICE cámara | dispositivo 8200-8207 | ~80% | 8 tipos | Analytics IA en evolución rápida |
| DEVICE medidor | dispositivo 8210-8213 | ~70% | 4 tipos | Protocolos legacy de utilities |
| DEVICE red/HSM | dispositivo 8220-8235 | ~85% | 16 tipos | Firmware/vendor específicos |
| VEHICLE | vehiculo 9100-9114 | ~80% | 15 tipos | Regulaciones por país; drones BVLOS |
| SERVICE | software 9200-9213 | ~85% | 14 tipos | Versiones futuras de protocolos |
| BOT | software 9230-9236 | ~85% | 7 tipos | Plataformas RPA nuevas |
| FEDERATED | software 9240-9253 | ~80% | 14 tipos | Nuevos IdP y wallets eIDAS 2.0 |
| AI_AGENT | software 9270-9284 | ~75% | 15 tipos | Arquitecturas de modelo en cambio permanente |

---

#### Por qué el 100% de cobertura es estructuralmente imposible

**Razón 1 — El catálogo es cerrado; el mundo es abierto**

`idn_tipo_atributo` es una enumeración finita de tipos conocidos hoy.
El mundo produce continuamente nuevos dispositivos (computación cuántica, implantes neurales,
sensores de campo cuántico), nuevos protocolos (Matter, Bluetooth 6.0, 5G NR V2X)
y nuevos actores (quantum agents, edge AI chips autónomos).
Un catálogo siempre modela el presente; nunca modela el futuro.

**Razón 2 — Los ENUMs internos heredan el mismo problema**

`tipo_sensor ENUM [temperatura, humedad, presion, ...]` — hay 800+ tipos de sensor con
estándares reconocidos. `protocolo_iot ENUM [MQTT, CoAP, ...]` — en 2026 existen 60+ variantes
de protocolo IoT activos. Cada ENUM dentro de `validation_policy` es un modelo cerrado
que también puede quedar incompleto o quedar obsoleto cuando cambia un estándar.

**Razón 3 — La validación depende del contexto (tenant / país / régimen regulatorio)**

El formato de NIT es diferente en Bolivia, Colombia y Perú.
El número de matrícula médica tiene reglas distintas según el Colegio Médico regional.
La `validation_policy` centralizada en el catálogo no puede parametrizar reglas por
contexto sin convertirse en código arbitrario que rompe la promesa del catálogo.
Esto requeriría una tabla separada de overrides por tenant — nivel de complejidad diferente.

**Razón 4 — Dependencias condicionales entre tipos que el catálogo no puede expresar**

Un lector de huella dactilar tiene `far_rate` pero no `faces_simultaneas`.
Un lector de iris tiene `angulo_vision_grados` con unidad diferente a un sensor de temperatura.
El campo `aplica_a TEXT[]` solo discrimina por `actor.tipo` (DEVICE, HUMAN, etc.) —
no puede expresar "el tipo_code 8101 solo aplica si tipo_code 8100 = 'huella_dactilar'".
Las dependencias condicionales entre tipos son relaciones de datos, no de catálogo.

**Razón 5 — Los cuatro verbos no cubren el compliance completo de datos**

READ / WRITE / VERIFY / EXPORT cubre el 80% de los casos de control de acceso.
Pero el compliance completo de GDPR Art. 15-22 y Ley 164 Bolivia requiere al menos:
- ANONYMIZE: pseudonimización sin exponer el original (Art. 25 GDPR)
- SHARE: transferencia a tercero con cadena de custodia auditada (Art. 46 GDPR)
- AGGREGATE: uso estadístico sin identificación individual (considerando 26 GDPR)
- BIND: vinculación de credencial a hardware específico (FIDO2 device binding)

Cuatro verbos es una decisión de diseño pragmática — no una cobertura completa de GDPR.

**Razón 6 — Tipos compuestos sin jerarquía explícita**

Una dirección postal tiene subestructura: calle, número, piso, municipio, departamento,
código postal, país. El catálogo actual solo puede modelarla como:
- Un tipo_code único `direccion_postal` con `value_data JSONB` opaco (pierde tipado)
- Siete tipos_codes separados sin relación padre-hijo explícita (pierde cohesión)

No existe el concepto de **tipo compuesto** en el DDL actual. Los atributos estructurados
quedan como JSONB libre dentro de `value_data`, rompiendo la promesa del catálogo controlado.

**Razón 7 — El límite físico de SMALLINT es real**

`tipo_code SMALLINT` → máximo 32,767.
Con rangos asignados hasta 9,284 y densidades de ~120 códigos por subcategoría de DEVICE,
una industria vertical (automatización, salud, finanzas) puede requerir 2,000+ tipos específicos.
El espacio aritmético alcanza (~23,483 libres), pero la profundidad real de cada industria
es ilimitada: un PLC Siemens S7-1500 tiene 200+ parámetros específicos de modelo.
No es un problema de espacio en SMALLINT — es un problema de modelo de datos conceptual.

---

#### La solución — válvula de escape formal (Extension Point)

El catálogo no debe prometer completitud. Debe prometer:
**"Todo lo conocido está tipado y controlado. Lo desconocido tiene un canal formal de ingreso."**

```
tipo_code = 9998  →  atributo_extension_texto
tipo_code = 9999  →  atributo_extension_jsonb
```

`idn_atributo` para estos dos tipos usa `value_data JSONB` con estructura libre:
```json
{
  "ext_tipo_key":    "velocidad_viento_kmh",
  "ext_categoria":   "dispositivo",
  "ext_descripcion": "Velocidad del viento del anemómetro Davis VP2",
  "ext_valor":       42.7,
  "ext_unidad":      "km/h",
  "ext_standard":    "WMO-No.8"
}
```

**Proceso de estandarización:**
cuando `atributo_extension` acumula 3+ entidades con `ext_tipo_key` igual
→ el SU propone un tipo_code formal en el catálogo (HITL)
→ el Revisor valida que el tipo es genérico y no específico de un tenant
→ se crea el tipo_code → las filas extension se migran al tipo formal

Este proceso convierte el catálogo de "promesa imposible de completitud"
en "núcleo controlado + extensión auditada + estandarización continua".

**Átomo D00 para la extensión:**
```
5828 + 1  →  D00.atributo.extension.leer
5828 + 2  →  D00.atributo.extension.escribir
```
El SU tiene acceso a escribir extensiones. Los roles normales solo pueden leer.
Roles de auditoría solo pueden leer + exportar.

---

#### Veredicto honesto

El modelo estructural (`idn_tipo_atributo` → `idn_atributo`) es correcto.
El catálogo con ~360+ tipos cubre el 70-97% de los actores según subcategoría.
El 3-30% restante no es un error de diseño — es la naturaleza del mundo abierto.
La cobertura del 100% es una **promesa falsa**: cualquier catálogo que la haga
es un catálogo que aún no ha encontrado el caso que lo rompe.

La arquitectura correcta es: **catálogo de núcleo + válvula de escape formal**.
El catálogo crece por estandarización continua — no por ingeniería especulativa.

---

## 9. Ejemplos completos por actor.tipo — filas reales en `idn_atributo`

Cada ejemplo muestra las filas que existirían en `idn_atributo` para una entidad concreta.
Las columnas `entidad_tipo` y `entidad_id` se omiten (se entiende que apuntan a la entidad del ejemplo).
`V` = `value_text`, `D` = `value_data JSONB`.

---

### 9.1 HUMAN — Empleado estándar

**Entidad:** Juan Carlos López Mamani · Jefe de Ventas · INCA Bolivia S.A.

| tipo_code | tipo_key | V (value_text) | D (value_data) | is_primary | is_verified |
|---|---|---|---|---|---|
| 1001 | nombre_legal_completo | "Juan Carlos López Mamani" | — | true | true |
| 1101 | fecha_nacimiento | "1985-03-15" | — | true | true |
| 1110 | genero | "masculino" | — | true | false |
| 2001 | telefono_movil | "+59175000001" | — | true | true |
| 2003 | telefono_fijo_trabajo | "+59122000099" | — | false | false |
| 2201 | email_personal | "jlopez@gmail.com" | — | false | true |
| 2202 | email_corporativo | "j.lopez@incabolivia.com" | — | true | true |
| 3101 | ci_bolivia | "4567890 LP" | — | true | true |
| 3201 | nit_bolivia | "4567890" | — | true | true |
| 4101 | direccion_calle | "Av. Arce 2345, Piso 3" | — | true | false |
| 4201 | ciudad | "La Paz" | — | true | false |
| 6001 | cargo_actual | "Jefe de Ventas" | — | true | false |
| 6010 | departamento | "Comercial" | — | true | false |
| 6020 | fecha_ingreso | "2018-05-01" | — | true | false |
| 5101 | cuenta_bancaria | — | `{"banco":"BNB","tipo":"ahorro","numero":"10012345678","moneda":"BOB"}` | true | true |

---

### 9.2 HUMAN — Menor de edad con tutor legal

**Entidad:** Valeria Quispe Condori · 13 años · dependiente del sistema familiar

| tipo_code | tipo_key | V (value_text) | D (value_data) | is_primary | is_verified |
|---|---|---|---|---|---|
| 1001 | nombre_legal_completo | "Valeria Quispe Condori" | — | true | true |
| 1101 | fecha_nacimiento | "2012-08-20" | — | true | true |
| 3101 | ci_bolivia | "9876543 CB" | — | true | true |
| 1112 | tutor_legal | "UUID-Ricardo-Quispe-padre" | — | true | true |
| 6028 | grado_escolar | "1ro Secundaria" | — | true | false |
| 6029 | institucion_educativa | "Colegio San Calixto La Paz" | — | true | false |
| 9013 | consentimiento_tutor | — | `{"tutor_id":"UUID-padre","fecha":"2026-01-15","tipo":"ingreso_sistema","documento":"consentimiento-valeria-2026.pdf"}` | true | true |
| 9014 | zona_acceso_permitida | — | `{"zonas":["Portal-Familiar"],"valido_desde":"2026-01-15","horario":"08:00-18:00"}` | true | false |

---

### 9.3 HUMAN — Profesional médico habilitado

**Entidad:** Dr. Roberto Vargas Torrez · Cirujano · Hospital San Juan de Dios Oruro

| tipo_code | tipo_key | V (value_text) | D (value_data) | is_primary | is_verified |
|---|---|---|---|---|---|
| 1001 | nombre_legal_completo | "Roberto Vargas Torrez" | — | true | true |
| 3101 | ci_bolivia | "5432109 OR" | — | true | true |
| 2001 | telefono_movil | "+59176000002" | — | true | true |
| 2202 | email_corporativo | "r.vargas@sanjuandedios.gob.bo" | — | true | true |
| 6001 | cargo_actual | "Médico Especialista Cirugía" | — | true | false |
| 9010 | matricula_medica | — | `{"numero":"COL-MED-OR-1234","colegio":"Colegio Médico de Oruro","vigencia":"2027-12-31","estado":"activa"}` | true | true |
| 9011 | area_medica_habilitada | — | `{"areas":["Cirugía General","Laparoscopía","UCI"],"certif_date":"2025-06-01","entidad":"Ministerio de Salud Bolivia"}` | true | true |
| 9014 | zona_acceso_permitida | — | `{"zonas":["Quirófano-1","UCI","Consultorios-3er-Piso","Farmacia-Interna"],"nivel_bioseguridad":"B2"}` | true | false |

---

### 9.4 HUMAN — Visitante / contratista externo

**Entidad:** Carlos Mendez Rios · Técnico de Mantenimiento · Otis Elevators Bolivia

| tipo_code | tipo_key | V (value_text) | D (value_data) | is_primary | is_verified |
|---|---|---|---|---|---|
| 1001 | nombre_legal_completo | "Carlos Mendez Rios" | — | true | false |
| 3101 | ci_bolivia | "6789012 LP" | — | true | false |
| 2001 | telefono_movil | "+59177000003" | — | true | false |
| 6030 | empresa_empleadora | "Otis Elevators Bolivia S.R.L." | — | true | false |
| 6031 | motivo_visita | "mantenimiento_preventivo" | — | true | false |
| 6032 | vehiculo_placa_visita | "3456-TLP" | — | false | false |
| 9014 | zona_acceso_permitida | — | `{"zonas":["Sala-Maquinas","Planta-Baja-Ascensor"],"valido_hasta":"2026-07-07T17:00:00Z","acompañante_requerido":true}` | true | false |

---

### 9.5 DEVICE — Lector biométrico de huella dactilar

**Entidad (Pos):** Lector-Biometrico-Recepcion-01 · ZKTeco SF100 · Edificio INCA La Paz

| tipo_code | tipo_key | V (value_text) | D (value_data) | is_primary |
|---|---|---|---|---|
| 8001 | nombre_dispositivo | "Lector-Biometrico-Recepcion-01" | — | true |
| 8002 | fabricante | "ZKTeco" | — | true |
| 8003 | modelo | "SF100" | — | true |
| 8004 | numero_serie | "ZKT2024-SF100-00123" | — | true |
| 8005 | firmware_version | "6.60 Build 20240301" | — | true |
| 8006 | direccion_mac | "A8:B1:C2:D3:E4:F5" | — | true |
| 8007 | direccion_ip | "192.168.10.51" | — | true |
| 8100 | tipo_biometrico | "huella_dactilar" | — | true |
| 8101 | far_rate | "0.0001%" | — | true |
| 8102 | frr_rate | "0.5%" | — | true |
| 8103 | sar_rate | "0.00001%" | — | true |
| 8104 | resolucion_sensor | "500 DPI" | — | true |
| 8105 | capacidad_templates | "3000" | — | true |
| 8106 | modo_operacion | "verificacion_1a1" | — | true |
| 8108 | nivel_pad | "ISO_30107_Nivel2" | — | true |
| 8109 | tiempo_respuesta_ms | "350" | — | true |
| 8111 | grado_proteccion_ip | "IP65" | — | true |
| 8112 | tipo_conector | "TCP_IP" | — | true |

> Nota: `tipo_biometrico = huella_dactilar` activa los tipos 8101-8119.
> Un lector de iris en el mismo tipo_code 8100 tendría `faces_simultaneas` y `angulo_vision_grados`
> en lugar de `resolucion_sensor` en DPI — dependencia condicional no expresable en el catálogo (Razón 4, §8.5).

---

### 9.6 DEVICE — Sensor IoT de temperatura (cámara frigorífica)

**Entidad (Pos):** Sensor-Temp-Camara-Fria-01 · Honeywell HIH6130 · Farmacéutica INTI La Paz

| tipo_code | tipo_key | V (value_text) | D (value_data) | is_primary |
|---|---|---|---|---|
| 8001 | nombre_dispositivo | "Sensor-Temp-Camara-Fria-01" | — | true |
| 8002 | fabricante | "Honeywell" | — | true |
| 8003 | modelo | "HIH6130" | — | true |
| 8004 | numero_serie | "HW2024-HIH-00456" | — | true |
| 8140 | tipo_sensor | "temperatura" | — | true |
| 8141 | rango_medicion | "-40°C a +85°C" | — | true |
| 8142 | precision_medicion | "±0.3°C" | — | true |
| 8143 | unidad_medicion | "°C" | — | true |
| 8144 | intervalo_muestreo_s | "60" | — | true |
| 8145 | protocolo_iot | "MQTT" | — | true |
| 8146 | gateway_id | "UUID-Gateway-Farmacia-01" | — | true |
| 8147 | ultimo_valor | — | `{"valor":-18.3,"timestamp":"2026-07-07T14:32:00Z","calidad":"GOOD"}` | true |
| 8148 | alerta_umbral | — | `{"min":-25.0,"max":-15.0,"accion":"notificar_bnotify","canal":"sms+email"}` | true |

---

### 9.7 DEVICE — PLC industrial (línea de producción)

**Entidad (Pos):** PLC-Linea-A-01 · Siemens S7-1515-2PN · Planta Embotelladora Cochabamba

| tipo_code | tipo_key | V (value_text) | D (value_data) | is_primary |
|---|---|---|---|---|
| 8001 | nombre_dispositivo | "PLC-Linea-A-01" | — | true |
| 8002 | fabricante | "Siemens" | — | true |
| 8003 | modelo | "S7-1515-2PN" | — | true |
| 8004 | numero_serie | "S7-2024-PLCA-0001" | — | true |
| 8150 | tipo_plc | "S7_1500" | — | true |
| 8151 | entradas_digitales | "32" | — | true |
| 8152 | salidas_digitales | "32" | — | true |
| 8153 | entradas_analogicas | "8" | — | true |
| 8154 | ciclo_scan_ms | "10" | — | true |
| 8155 | nivel_sil | "SIL_2" | — | true |
| 8156 | red_industrial | "PROFINET" | — | true |
| 8157 | protocolo_scada | "OPC_UA" | — | true |
| 8158 | version_firmware | "V3.1.3" | — | true |
| 8159 | certif_ce | — | `{"cert":"CE","norma":"IEC 61131-2","fecha":"2024-01-15","laboratorio":"TÜV SÜD"}` | true |

---

### 9.8 DEVICE — ATM (cajero automático)

**Entidad (Pos):** ATM-Sopocachi-01 · Diebold Nixdorf DN200 · Banco BNB La Paz

| tipo_code | tipo_key | V (value_text) | D (value_data) | is_primary |
|---|---|---|---|---|
| 8001 | nombre_dispositivo | "ATM-Sopocachi-01" | — | true |
| 8002 | fabricante | "Diebold Nixdorf" | — | true |
| 8003 | modelo | "DN200" | — | true |
| 8004 | numero_serie | "DN2024-200-00789" | — | true |
| 8007 | direccion_ip | "10.10.5.201" | — | true |
| 8180 | num_cassettes | "4" | — | true |
| 8181 | capacidad_billetes_por_cassette | "2000" | — | true |
| 8182 | certif_pci_pts | "PCI PTS 6.0 SRED" | — | true |
| 8183 | nivel_p2pe | "PCI P2PE v3.0" | — | true |
| 8184 | nivel_xfs | "XFS 3.30" | — | true |
| 8185 | conexion_red | "TCP_IP_TLS1_3" | — | true |
| 8186 | os_base | "Windows 10 IoT Enterprise LTSC 2021" | — | true |
| 8187 | hdd_cifrado | — | `{"cifrado":true,"algoritmo":"AES-256","tpm":"TPM 2.0"}` | true |
| 8188 | anticopy_sensor | "true" | — | true |

---

### 9.9 DEVICE — Cámara IP con analytics IA

**Entidad (Pos):** Cam-Estacionamiento-NE-01 · Axis Q6225-LE · Playa de estacionamiento INCA

| tipo_code | tipo_key | V (value_text) | D (value_data) | is_primary |
|---|---|---|---|---|
| 8001 | nombre_dispositivo | "Cam-Estacionamiento-NE-01" | — | true |
| 8002 | fabricante | "Axis" | — | true |
| 8003 | modelo | "Q6225-LE" | — | true |
| 8007 | direccion_ip | "192.168.20.15" | — | true |
| 8200 | tipo_camara | "ptz_exterior_noche" | — | true |
| 8201 | resolucion_video | "1920x1080" | — | true |
| 8202 | fps_max | "30" | — | true |
| 8203 | vision_nocturna_m | "50" | — | true |
| 8204 | angulo_vision_grados | "360" | — | true |
| 8205 | compresion_video | "H.265" | — | true |
| 8206 | almacenamiento_dias | "30" | — | true |
| 8207 | analytics_ia | — | `{"tipos":["lpr","people_counting"],"motor":"AXIS Object Analytics 2.0","fps_inferencia":25,"modelo_lpr":"latino_america_v3"}` | true |

---

### 9.10 VEHICLE — Vehículo de flota corporativa

**Entidad (Actor DEVICE):** Toyota-Corolla-Flota-LP-003 · Toyota Corolla 2022 · Flota INCA La Paz

| tipo_code | tipo_key | V (value_text) | D (value_data) | is_primary |
|---|---|---|---|---|
| 9100 | placa_vehiculo | "3456-TLP" | — | true |
| 9101 | vin | "JTDBU4EE5BJ034567" | — | true |
| 9102 | tipo_vehiculo | "sedan" | — | true |
| 9103 | marca | "Toyota" | — | true |
| 9104 | modelo_vehiculo | "Corolla" | — | true |
| 9105 | año_fabricacion | "2022" | — | true |
| 9106 | color | "Blanco" | — | true |
| 9107 | num_asientos | "5" | — | true |
| 9108 | soat_numero | "SOAT-2026-456789" | — | true |
| 9109 | soat_vencimiento | "2026-12-31" | — | true |
| 9110 | seguro_poliza | "POL-BISA-789012" | — | true |
| 9111 | propietario_id | "UUID-INCA-Bolivia-SA" | — | true |
| 9112 | conductor_asignado_id | "UUID-Pedro-Chofer" | — | true |

---

### 9.11 SERVICE — Daemon bAuth registrado como actor

**Entidad (Actor SERVICE):** bauth · Identity Control Plane · servidor S03-identity

| tipo_code | tipo_key | V (value_text) | D (value_data) | is_primary |
|---|---|---|---|---|
| 9200 | nombre_servicio | "bauth" | — | true |
| 9201 | hash_binario | — | `{"sha256":"a3f1e2d4b5c6e7f8...","build_date":"2026-07-01","tag":"v3.0.0","musl":true}` | true |
| 9202 | socket_path | "/run/bos/bauth.sock" | — | true |
| 9203 | puerto_proceso | "9450" | — | true |
| 9204 | sbom | — | `{"spdx_version":"2.3","formato":"json","hash":"sha256:c4d5e6f7...","ubicacion":"sbom/bauth-v3.0.0.spdx.json"}` | true |
| 9205 | cve_scan_fecha | "2026-07-01" | — | true |
| 9206 | cve_score_max | "0.0" | — | true |

---

### 9.12 BOT — Job de generación de reportes SIN

**Entidad (Actor BOT):** ReportBot-Facturacion-Mensual · proceso cron en S03-identity

| tipo_code | tipo_key | V (value_text) | D (value_data) | is_primary |
|---|---|---|---|---|
| 8001 | nombre_dispositivo | "ReportBot-Facturacion-Mensual" | — | true |
| 9230 | tipo_bot | "report_generator" | — | true |
| 9231 | schedule_cron | "0 3 1 * *" | — | true |
| 9232 | tiempo_ejecucion_s | "180" | — | true |
| 9233 | propietario_funcional | "UUID-Gerente-Administrativo" | — | true |
| 9235 | sistema_objetivo | "biedata.json-rpc + tryton.account.move" | — | true |
| 9236 | credenciales_vault | "secret/sbos/reportbot/db-credentials" | — | true |

> `credenciales_vault` nunca expone la credencial — solo la ruta en Vault. El bot la lee en runtime.

---

### 9.13 FEDERATED — Usuario con identidad externa Google Workspace

**Entidad (Actor FEDERATED):** Maria González · consultora externa · autenticada vía Google

| tipo_code | tipo_key | V (value_text) | D (value_data) | is_primary |
|---|---|---|---|---|
| 1001 | nombre_legal_completo | "Maria González Pérez" | — | true |
| 2201 | email_personal | "m.gonzalez@consultora.com" | — | true |
| 9240 | idp_tipo | "oidc" | — | true |
| 9241 | idp_email_verified | "true" | — | true |
| 9242 | idp_acr | "urn:mace:incommon:iap:silver" | — | true |
| 9243 | idp_amr | — | `{"metodos":["pwd","otp"],"otp_app":"Google Authenticator"}` | true |

---

### 9.14 FEDERATED — Ciudadano europeo con eIDAS Wallet

**Entidad (Actor FEDERATED):** Klaus Weber · proveedor alemán · identidad eIDAS 2.0

| tipo_code | tipo_key | V (value_text) | D (value_data) | is_primary |
|---|---|---|---|---|
| 1001 | nombre_legal_completo | "Klaus Friedrich Weber" | — | true |
| 9240 | idp_tipo | "eidas_wallet" | — | true |
| 9250 | eidas_level | "high" | — | true |
| 9251 | eidas_pid_hash | — | `{"algoritmo":"sha256","hash":"b2c3d4e5f6a1b2c3...","issuer":"BSI Germany","fecha":"2026-01-10"}` | true |

---

### 9.15 FEDERATED — Usuario de Active Directory corporativo externo

**Entidad (Actor FEDERATED):** Pedro Suárez · usuario sincronizado desde AD de empresa afiliada

| tipo_code | tipo_key | V (value_text) | D (value_data) | is_primary |
|---|---|---|---|---|
| 1001 | nombre_legal_completo | "Pedro Suárez Rojas" | — | true |
| 9240 | idp_tipo | "active_directory" | — | true |
| 9241 | idp_email_verified | "true" | — | true |
| 9252 | ldap_dn | "CN=Pedro Suárez,OU=IT,DC=empresa-afiliada,DC=com" | — | true |
| 9253 | ldap_sid | "S-1-5-21-3165297888-123456789-987654321-1001" | — | true |

---

### 9.16 AI_AGENT — Agente IA desarrollador de bAuth

**Entidad (Actor AI_AGENT):** bauth-developer · Claude Sonnet 4.6 · sesión activa en BauthAgent/src

| tipo_code | tipo_key | V (value_text) | D (value_data) | is_primary |
|---|---|---|---|---|
| 8001 | nombre_dispositivo | "bauth-developer" | — | true |
| 9270 | version_modelo_ia | "claude-sonnet-4-6-20250514" | — | true |
| 9271 | contexto_max_tokens | "200000" | — | true |
| 9272 | tool_access | — | `{"tools":["Read","Write","Edit","Bash","Agent","Artifact"],"restricciones":["sin-acceso-internet-externo"]}` | true |
| 9273 | project_scope | "SBOS/BauthAgent" | — | true |
| 9274 | aprobacion_hitl | "para_destructivos" | — | true |

---

### 9.17 DEVICE — Tipo desconocido → válvula de escape (tipo_code 9999)

**Entidad (Pos):** Sensor-IAQ-Laboratorio-01 · Sensirion SEN55 · protocolo propietario UART
Ningún tipo_code del catálogo cubre exactamente este sensor de calidad de aire con protocolo UART custom.
Se registra con `atributo_extension_jsonb` (9999) hasta que se formalice el tipo.

| tipo_code | tipo_key | V (value_text) | D (value_data) | is_primary |
|---|---|---|---|---|
| 8001 | nombre_dispositivo | "Sensor-IAQ-Laboratorio-01" | — | true |
| 8002 | fabricante | "Sensirion" | — | true |
| 8003 | modelo | "SEN55" | — | true |
| 9999 | atributo_extension_jsonb | — | `{"ext_tipo_key":"calidad_aire_iaq","ext_categoria":"dispositivo","ext_descripcion":"Índice IAQ multi-parámetro Sensirion SEN55","ext_valor":{"pm25":12.3,"pm10":18.7,"voc":0.8,"nox":0.1,"iaq":45},"ext_unidad":"μg/m³ + IAQ","ext_protocolo":"UART_custom_115200","ext_standard":"ISO 16890"}` | true |

> Cuando otros 2 sensores del mismo tipo se registren con `ext_tipo_key = "calidad_aire_iaq"`,
> el SU propone tipo_code formal en el catálogo (proceso de estandarización §8.5).

---

### 9.18 Lectura transversal — un solo actor usa múltiples categorías

Un **empleado médico que también conduce vehículo de flota y accede vía AD externo**
concentra atributos de 5 categorías distintas:

```
entidad_tipo = 'actor'
entidad_id   = UUID-DrPedroSuarez

tipo_code  tipo_key                  value
─────────────────────────────────────────────────────────────────────────
 1001      nombre_legal_completo     "Pedro Suárez Alvarado"
 3101      ci_bolivia                "7654321 LP"
 9010      matricula_medica          {numero: "COL-MED-LP-5678", vigencia: "2028-12-31"}
 9011      area_medica_habilitada    {areas: ["Cardiología", "UCI"]}
 9252      ldap_dn                   "CN=PSuarez,OU=Medicos,DC=hospital,DC=gob,DC=bo"
 9100      placa_vehiculo            "7890-TLP"        ← placa del auto asignado
 9112      conductor_asignado_id     "UUID-Pedro-mismo" ← self-reference
 9014      zona_acceso_permitida     {zonas: ["UCI","Cardiología","Estacionamiento-Médicos"]}
```

Un solo actor, 5 categorías: `personal`, `documento`, `medico` (nuevo), `software` (LDAP),
`vehiculo`. El modelo `idn_atributo` lo soporta sin cambios de esquema — solo filas nuevas.

---

---

## 10. Metadata UI/CRUD — Icono, etiqueta, hint y compliance por tipo

### 10.1 Nuevos campos identificados — investigación industrial

| Campo | Tipo SQL | Fuente estándar | Propósito en CRUD |
|---|---|---|---|
| `icono` | TEXT | UX industry (Material Icons, Fluent UI, WCAG 2.2) | Identificación visual rápida en tablas y formularios |
| `etiqueta_corta` | TEXT | Okta Schema API · SCIM 2.0 `displayName` | Cabecera de columna (≤15 chars) |
| `hint_crud` | TEXT | HTML5 `title`/`aria-describedby` · W3C WCAG 2.2 | Texto de ayuda bajo el campo en formularios |
| `grupo_formulario` | TEXT | Okta Profile Editor · Azure AD Schema Extensions | Pestaña/sección del formulario donde aparece |
| `orden_en_grupo` | SMALLINT | Okta Profile Editor display_order | Posición dentro del grupo (menor = primero) |
| `es_requerido` | BOOLEAN | SCIM 2.0 RFC 7643 `required` | Marca campo como obligatorio al crear la entidad |
| `mutabilidad` | TEXT | SCIM 2.0 RFC 7643 §7.2 `mutability` | readWrite / readOnly / immutable / writeOnly |
| `unicidad` | TEXT | SCIM 2.0 RFC 7643 §7.2 `uniqueness` | none / por_entidad / global |
| `gdpr_categoria` | TEXT | GDPR Art. 9 · ISO 29101:2018 · ISO 27701:2019 | Clasificación de privacidad para color en UI |
| `retencion_dias` | INT | GDPR Art. 5(1)(e) · Ley 027 Bolivia | Días de retención antes de eliminación obligatoria |
| `requiere_dpia` | BOOLEAN | GDPR Art. 35 · ISO 29134:2023 | Requiere Evaluación de Impacto sobre la Privacidad |
| `ial_minimo` | TEXT | NIST SP 800-63A Rev.4 IAL1-3 | Nivel mínimo de identity proofing para registrar |
| `servicio_verificacion` | TEXT | Industry: email OTP, SMS, SEGIP, SIN, ADSIB, banco | Servicio que verifica el valor y activa `is_verified` |
| `scim_name` | TEXT | SCIM 2.0 RFC 7643 · RFC 7644 | Nombre canónico SCIM para interoperabilidad API |
| `oidc_claim` | TEXT | OIDC Core 1.0 §5.1 standard claims | Claim equivalente en JWT/UserInfo endpoint |

**Leyenda de abreviaciones usada en las tablas §10.4+:**

```
gdpr  →  🟢 ordinario  |  🟡 especial_art9 (GDPR Art.9)  |  👆 biométrico  |  🟠 financiero
mut   →  RW = readWrite  |  RO = readOnly  |  IM = immutable  |  WO = writeOnly
ial   →  A0 = autoafirmado  |  L2 = IAL2 (remoto)  |  L3 = IAL3 (presencial)  |  SYS = sistema
```

---

### 10.2 DDL — columnas a agregar a `idn_tipo_atributo`

```sql
-- HITL requerido antes de ejecutar
ALTER TABLE bauth.idn_tipo_atributo
    ADD COLUMN IF NOT EXISTS icono              TEXT,
    ADD COLUMN IF NOT EXISTS etiqueta_corta     TEXT,
    ADD COLUMN IF NOT EXISTS hint_crud          TEXT,
    ADD COLUMN IF NOT EXISTS grupo_formulario   TEXT
        CONSTRAINT ck_grupo_form CHECK (grupo_formulario IN (
            'datos_basicos','contacto','documentos','profesional',
            'financiero','tecnico','seguridad','suscripcion')),
    ADD COLUMN IF NOT EXISTS orden_en_grupo     SMALLINT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS es_requerido       BOOLEAN  NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS mutabilidad        TEXT     NOT NULL DEFAULT 'readWrite'
        CONSTRAINT ck_mutabilidad CHECK (mutabilidad IN
            ('readWrite','readOnly','immutable','writeOnly')),
    ADD COLUMN IF NOT EXISTS unicidad           TEXT     NOT NULL DEFAULT 'none'
        CONSTRAINT ck_unicidad CHECK (unicidad IN
            ('none','por_entidad','global')),
    ADD COLUMN IF NOT EXISTS scim_name          TEXT,
    ADD COLUMN IF NOT EXISTS oidc_claim         TEXT,
    ADD COLUMN IF NOT EXISTS gdpr_categoria     TEXT     NOT NULL DEFAULT 'ordinario'
        CONSTRAINT ck_gdpr_cat CHECK (gdpr_categoria IN (
            'ordinario','especial_art9','biometrico','financiero','anonimo')),
    ADD COLUMN IF NOT EXISTS requiere_dpia      BOOLEAN  NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS retencion_dias     INT,
    ADD COLUMN IF NOT EXISTS ial_minimo         TEXT     NOT NULL DEFAULT 'autoafirmado'
        CONSTRAINT ck_ial CHECK (ial_minimo IN
            ('autoafirmado','IAL1','IAL2','IAL3','sistema')),
    ADD COLUMN IF NOT EXISTS servicio_verificacion TEXT
        CONSTRAINT ck_serv_verif CHECK (servicio_verificacion IN (
            'ninguno','email_smtp','sms_otp','totp','sin_bolivia',
            'segip_bolivia','adsib','banco','manual','fido2'));
```

---

### 10.3 Ejemplo tipo completo — `telefono_movil` (tipo_code = 2001)

```
tipo_code            = 2001
categoria            = 'contacto'
tipo_key             = 'telefono_movil'
tipo_nombre          = 'Teléfono Móvil'
tipo_nombre_en       = 'Mobile Phone'
descripcion          = 'Número de teléfono móvil en formato E.164 con código de país'
display_format       = 'E164'
mask                 = '+## (###) ###-####'
placeholder          = '+591 71234567'
validation_policy    = {"regex":"^\\+[1-9]\\d{7,14}$","normalize":"E164_ITU","standard_ref":"ITU-T E.164"}
atom_read            = 5814     -- D00.org.bdomain.telefono
atom_write           = 5829     -- nuevo verbo WRITE
atom_verify          = 5830     -- nuevo verbo VERIFY
atom_export          = 5831     -- nuevo verbo EXPORT (GDPR portabilidad)
aplica_a             = '{tenant,bdomain,bsubdomain,pos,actor}'
es_multiple          = true
es_verificable       = true
es_sensible          = false
muestra_enmascarado  = true

-- CAMPOS NUEVOS §10
icono                = '📱'
etiqueta_corta       = 'Tel. Móvil'
hint_crud            = 'Incluya código de país. Ej: +591 71234567'
grupo_formulario     = 'contacto'
orden_en_grupo       = 1
es_requerido         = false
mutabilidad          = 'readWrite'
unicidad             = 'none'
gdpr_categoria       = 'ordinario'
requiere_dpia        = false
retencion_dias       = 1825     -- 5 años (obligaciones laborales)
ial_minimo           = 'autoafirmado'
servicio_verificacion = 'sms_otp'
scim_name            = 'phoneNumbers.value'
oidc_claim           = 'phone_number'
standard_ref         = 'ITU-T E.164 · SCIM 2.0 RFC 7643 · OIDC Core 1.0'
```

---

### 10.4 Metadata CRUD — categoría `personal` · nombre (1001-1011)

| tc | 🎨 | etiq | gdpr | mut | ial | hint_crud |
|---|---|---|---|---|---|---|
| 1001 | 👤 | Primer Nombre | 🟢 | RW | A0 | Solo nombre(s) de pila, sin apellidos |
| 1002 | 👤 | 2do Nombre | 🟢 | RW | A0 | Segundo nombre si lo tiene |
| 1003 | 👤 | 3er Nombre | 🟢 | RW | A0 | Tercer nombre (infrecuente) |
| 1004 | 👤 | Ap. Paterno | 🟢 | RW | A0 | Primer apellido |
| 1005 | 👤 | Ap. Materno | 🟢 | RW | A0 | Segundo apellido |
| 1006 | 💍 | Ap. Casada | 🟢 | RW | A0 | Apellido adquirido por matrimonio |
| 1007 | 👤 | Ap. Compuesto | 🟢 | RW | A0 | Apellido unido con guión (ej: García-López) |
| 1008 | 💬 | Nom. Preferido | 🟢 | RW | A0 | Cómo prefiere que lo llamen |
| 1009 | 📋 | Nom. Legal | 🟢 | RW | A0 | Nombre completo como en CI o Pasaporte |
| 1010 | 🏷️ | Nom. Comercial | 🟢 | RW | A0 | Nombre de marca o razón social |
| 1011 | 🌐 | Nom. Extranjero | 🟢 | RW | A0 | Nombre en idioma o país alternativo |

**SCIM mapping:** `name.givenName` (1001) · `name.familyName` (1004) · `name.formatted` (1009)
**OIDC mapping:** `given_name` (1001) · `family_name` (1004) · `name` (1009)
**grupo_formulario:** `datos_basicos` · **retencion_dias:** 3650 (10 años)

---

### 10.5 Metadata CRUD — categoría `personal` · biográfico (1101-1113)

| tc | 🎨 | etiq | gdpr | mut | ial | hint_crud |
|---|---|---|---|---|---|---|
| 1101 | 🎂 | Fecha Nac. | 🟢 | RW | A0 | Formato AAAA-MM-DD · Ej: 1990-03-15 |
| 1102 | ⚧️ | Género | 🟡 | RW | A0 | M / F / NB / NR / X — Art. 9 GDPR |
| 1103 | 💍 | Estado Civil | 🟢 | RW | A0 | soltero / casado / divorciado / viudo / union_libre |
| 1104 | 🩸 | Tipo Sangre | 🟡 | RW | A0 | A+ A- B+ B- AB+ AB- O+ O- — dato de salud |
| 1105 | 🌍 | Nacionalidad | 🟢 | RW | A0 | Código ISO 3166-1 alpha-2 · Ej: BO, AR, US |
| 1106 | 🗣️ | Idioma | 🟢 | RW | A0 | BCP47 · Ej: es-BO, en-US, pt-BR |
| 1107 | 🗣️ | Idioma Adic. | 🟢 | RW | A0 | Idioma adicional en BCP47 |
| 1108 | 🕐 | Zona Horaria | 🟢 | RW | A0 | IANA · Ej: America/La_Paz |
| 1109 | 📍 | País Nac. | 🟢 | RW | A0 | País de nacimiento ISO 3166-1 alpha-2 |
| 1110 | 📍 | Lugar Nac. | 🟢 | RW | A0 | Ciudad o localidad de nacimiento |
| 1111 | 👶 | Menor Edad | 🟢 | RO | SYS | Calculado desde fecha_nacimiento — no editable |
| 1112 | 🛡️ | Tutor Legal | 🟢 | RW | L2 | UUID del actor tutor — verificación obligatoria |
| 1113 | 🌍 | País Resid. | 🟢 | RW | A0 | País de residencia actual ISO 3166-1 alpha-2 |

**SCIM mapping:** `urn:ietf:params:scim:schemas:core:2.0:User:timezone` (1108)
**OIDC mapping:** `birthdate` (1101) · `gender` (1102) · `zoneinfo` (1108) · `locale` (1106)
**retencion_dias:** 1102/1104 → 365 (1 año post-egreso, datos sensibles) · resto → 3650

---

### 10.6 Metadata CRUD — categoría `contacto` · teléfonos (2001-2010)

| tc | 🎨 | etiq | gdpr | mut | ial | hint_crud |
|---|---|---|---|---|---|---|
| 2001 | 📱 | Tel. Móvil | 🟢 | RW | A0 | E.164 · Ej: +591 71234567 · se verifica por SMS |
| 2002 | 📞 | Tel. Fijo | 🟢 | RW | A0 | E.164 · Ej: +591 22345678 · código de área incluido |
| 2003 | ☎️ | Tel. Trabajo | 🟢 | RW | A0 | Teléfono de la oficina con código de área |
| 2004 | 🆘 | Tel. Emergencia | 🟢 | RW | A0 | Quién llamar en emergencia — no se usa para login |
| 2005 | 📠 | Fax | 🟢 | RW | A0 | Número de fax E.164 |
| 2006 | 🔢 | Extensión | 🟢 | RW | A0 | Sólo dígitos · Ej: ext. 2345 |
| 2007 | 💬 | WhatsApp | 🟢 | RW | A0 | Mismo número que Tel. Móvil en formato E.164 |
| 2008 | ✈️ | Telegram | 🟢 | RW | A0 | Username con @ · Ej: @nombre_usuario |
| 2009 | 🔒 | Signal | 🟢 | RW | A0 | Número registrado en Signal en formato E.164 |
| 2010 | 📲 | Viber | 🟢 | RW | A0 | Número Viber en formato E.164 |

**SCIM mapping:** `phoneNumbers.value` (todos) · `phoneNumbers.type`: work/mobile/home/fax/other
**OIDC mapping:** `phone_number` (2001) · `phone_number_verified` (read-only, tras verificación)
**servicio_verificacion:** 2001/2007 → `sms_otp` · 2002 → `manual` · resto → `ninguno`

---

### 10.7 Metadata CRUD — categoría `contacto` · emails (2101-2109)

| tc | 🎨 | etiq | gdpr | mut | ial | hint_crud |
|---|---|---|---|---|---|---|
| 2101 | 📧 | Email Personal | 🟢 | RW | A0 | email@dominio.com · se enviará link de verificación |
| 2102 | 📨 | Email Trabajo | 🟢 | RW | A0 | email@empresa.com · correo corporativo |
| 2103 | 🧾 | Email Factur. | 🟢 | RW | A0 | Recibe facturas y documentos fiscales |
| 2104 | ⚖️ | Email Legal | 🟢 | RW | A0 | Para notificaciones judiciales o legales |
| 2105 | 🎧 | Email Soporte | 🟢 | RW | A0 | Para tickets de soporte técnico |
| 2106 | 🔑 | Email Recup. | 🟢 | RW | A0 | Email alternativo para recuperar acceso — sensible |
| 2107 | 👥 | Email RRHH | 🟢 | RW | A0 | Para comunicaciones de recursos humanos |
| 2108 | 📰 | Email Prensa | 🟢 | RW | A0 | Contacto para medios y relaciones públicas |
| 2109 | 💼 | Email Ventas | 🟢 | RW | A0 | Contacto para consultas comerciales |

**SCIM mapping:** `emails.value` (todos) · `emails.type`: work/home/other/billing
**OIDC mapping:** `email` (2101) · `email_verified` (read-only, tras verificación)
**servicio_verificacion:** 2101/2102/2106 → `email_smtp` · resto → `ninguno`

---

### 10.8 Metadata CRUD — categoría `contacto` · redes sociales (2201-2209)

| tc | 🎨 | etiq | gdpr | mut | ial | hint_crud |
|---|---|---|---|---|---|---|
| 2201 | 💼 | LinkedIn | 🟢 | RW | A0 | URL completa · Ej: https://linkedin.com/in/usuario |
| 2202 | 🐦 | Twitter/X | 🟢 | RW | A0 | Username con @ · Ej: @usuario |
| 2203 | 📸 | Instagram | 🟢 | RW | A0 | Username con @ · Ej: @usuario |
| 2204 | 👥 | Facebook | 🟢 | RW | A0 | URL del perfil · Ej: facebook.com/usuario |
| 2205 | 🐙 | GitHub | 🟢 | RW | A0 | URL del perfil · Ej: github.com/usuario |
| 2206 | 🎬 | YouTube | 🟢 | RW | A0 | URL del canal de YouTube |
| 2207 | 🎵 | TikTok | 🟢 | RW | A0 | Username con @ · Ej: @usuario |
| 2208 | 🌐 | Sitio Web | 🟢 | RW | A0 | URL completa con https:// |
| 2209 | 💬 | WhatsApp Biz | 🟢 | RW | A0 | Número WhatsApp Business E.164 |

**SCIM mapping:** `urn:ietf:params:scim:schemas:extension:…:socialMedia` (extensión)
**OIDC mapping:** `website` (2208) · `profile` (2201)
**grupo_formulario:** `contacto` · **retencion_dias:** 1825 (5 años)

---

### 10.9 Metadata CRUD — categoría `documento` · identidad (3001-3028)

| tc | 🎨 | etiq | gdpr | mut | ial | hint_crud |
|---|---|---|---|---|---|---|
| 3001 | 🪪 | CI Bolivia | 🟢 | RW | L2 | 7-8 dígitos + dpto. · Ej: 4567890 LP · SEGIP |
| 3002 | 🪪 | DNI Argentina | 🟢 | RW | L2 | 7-8 dígitos sin puntos · Ej: 12345678 |
| 3003 | 🪪 | CPF Brasil | 🟢 | RW | L2 | 11 dígitos · Ej: 123.456.789-09 |
| 3004 | 🪪 | RUT Chile | 🟢 | RW | L2 | Con dígito verificador · Ej: 12.345.678-9 |
| 3005 | 🪪 | CURP México | 🟢 | RW | L2 | 18 caracteres alfanuméricos |
| 3006 | 🪪 | DUI El Salv. | 🟢 | RW | L2 | 9 dígitos · Ej: 12345678-9 |
| 3007 | 🪪 | DNI Perú | 🟢 | RW | L2 | 8 dígitos exactos |
| 3008 | 🪪 | Cédula Col. | 🟢 | RW | L2 | 6-10 dígitos según tipo |
| 3009 | 🪪 | Cédula Ecua. | 🟢 | RW | L2 | 10 dígitos con módulo 10 |
| 3010 | 🪪 | Cédula Vene. | 🟢 | RW | L2 | V/E + 6-8 dígitos · Ej: V-12345678 |
| 3011 | 🪪 | CI Uruguay | 🟢 | RW | L2 | Con dígito verificador · Ej: 1.234.567-8 |
| 3012 | 🪪 | CI Paraguay | 🟢 | RW | L2 | 7-8 dígitos · Ej: 1.234.567 |
| 3013 | 🛂 | Pasaporte | 🟢 | RW | L2 | ICAO 9303 · alfanumérico del pasaporte |
| 3014 | 🌐 | Permiso Resid. | 🟢 | RW | L2 | Número del permiso de residencia |
| 3015 | ✈️ | Visa | 🟢 | RW | L2 | Número de visa y país emisor |
| 3016 | 🚗 | Lic. Conducir | 🟢 | RW | L2 | Número de licencia según el país |
| 3017 | 🪪 | DNI España | 🟢 | RW | L2 | 8 dígitos + letra · Ej: 12345678A |
| 3018 | 🪪 | CI Francia | 🟢 | RW | L2 | Número de la Carte Nationale d'Identité |
| 3019 | 🪪 | Perso. Ale. | 🟢 | RW | L2 | Personalausweis alemán |
| 3020 | 🪪 | CI Italia | 🟢 | RW | L2 | Carta d'Identità italiana |
| 3021 | 🔒 | SSN USA | 🟢 | RW | L3 | ### - ## - #### · siempre enmascarado |
| 3022 | 🏥 | NHS UK | 🟢 | RW | L2 | 10 dígitos NHS Number |
| 3023 | 🔗 | DID W3C | 🟢 | RW | A0 | did:method:id · identificador descentralizado |
| 3024 | 🇪🇺 | EUDI Wallet | 🟢 | RO | SYS | eIDAS 2.0 — emitido por autoridad europea |
| 3025 | 🏛️ | Carnet Func. | 🟢 | RW | L2 | Carnet de funcionario público |
| 3026 | 📋 | Matríc. Prof. | 🟢 | RW | L2 | N° matrícula colegio profesional |
| 3027 | 💰 | Carnet AFP | 🟢 | RW | L2 | N° afiliado AFP o fondo de pensiones |
| 3028 | 🏥 | Carnet Seguro | 🟢 | RW | L2 | N° afiliado al seguro médico |

**SCIM mapping:** no hay mapeo estándar SCIM para documentos nacionales (extensión empresarial)
**servicio_verificacion:** 3001 → `segip_bolivia` · 3013 → `manual` · 3021 → `manual` (alto riesgo)
**grupo_formulario:** `documentos` · **es_sensible:** true (todos) · **muestra_enmascarado:** true

---

### 10.10 Metadata CRUD — categoría `documento` · tributario (3101-3120)

| tc | 🎨 | etiq | gdpr | mut | ial | hint_crud |
|---|---|---|---|---|---|---|
| 3101 | 🏛️ | NIT Bolivia | 🟢 | RW | L2 | 7-10 dígitos · verificar con SIN Bolivia |
| 3102 | 🏛️ | RUC Perú | 🟢 | RW | L2 | 11 dígitos · verificar con SUNAT |
| 3103 | 🏛️ | RUC Ecuador | 🟢 | RW | L2 | 13 dígitos |
| 3104 | 🏛️ | CNPJ Brasil | 🟢 | RW | L2 | 14 dígitos · Ej: 12.345.678/0001-99 |
| 3105 | 🏛️ | CPF Brasil | 🟢 | RW | L2 | CPF persona física — uso tributario |
| 3106 | 🏛️ | CUIT Argentina | 🟢 | RW | L2 | Con dígito verificador · Ej: 20-12345678-9 |
| 3107 | 🏛️ | RFC México | 🟢 | RW | L2 | 12-13 caracteres alfanuméricos |
| 3108 | 🏛️ | VAT Europa | 🟢 | RW | L2 | XX + número según país UE |
| 3109 | 🏛️ | EIN USA | 🟢 | RW | L2 | Employer ID · Ej: 12-3456789 |
| 3110 | 🏛️ | NIF España | 🟢 | RW | L2 | 8 dígitos + letra verificadora |
| 3111 | 🏛️ | SIRET Francia | 🟢 | RW | L2 | 14 dígitos |
| 3112 | 🏛️ | USt Alemania | 🟢 | RW | L2 | DE + 9 dígitos · Ej: DE123456789 |
| 3113 | 🏛️ | P.IVA Italia | 🟢 | RW | L2 | IT + 11 dígitos |
| 3114 | 🏛️ | KvK Holanda | 🟢 | RW | L2 | 8 dígitos |
| 3115 | 🏛️ | Fiscal Gen. | 🟢 | RW | L2 | Identificador fiscal — para países no listados |
| 3116 | 🏛️ | RUT Chile | 🟢 | RW | L2 | Con dígito verificador · uso tributario |
| 3117 | 🏛️ | NIT Colombia | 🟢 | RW | L2 | 9 dígitos + dígito verificador |
| 3118 | 🏛️ | RIF Venezuela | 🟢 | RW | L2 | J/G/V/E + 8 dígitos |
| 3119 | 🏛️ | RUC Paraguay | 🟢 | RW | L2 | 7-8 dígitos + verificador |
| 3120 | 🏛️ | RUT Uruguay | 🟢 | RW | L2 | 8 dígitos + verificador |

**servicio_verificacion:** 3101 → `sin_bolivia` · 3102 → `manual` · resto → `manual`
**grupo_formulario:** `documentos` · **unicidad:** `por_entidad` · **retencion_dias:** 3650

---

### 10.11 Metadata CRUD — categoría `ubicacion` (4001-4005)

| tc | 🎨 | etiq | gdpr | mut | ial | hint_crud |
|---|---|---|---|---|---|---|
| 4001 | 🏛️ | Dir. Fiscal | 🟢 | RW | A0 | Dirección ante el fisco — {calle, ciudad, pais_code} |
| 4002 | 🏢 | Dir. Operativa | 🟢 | RW | A0 | Sede donde opera — puede diferir de la fiscal |
| 4003 | 📦 | Dir. Entrega | 🟢 | RW | A0 | Incluir referencia visual para el mensajero |
| 4004 | 🏠 | Dir. Personal | 🟢 | RW | A0 | Domicilio personal — solo accesible con permisos |
| 4005 | 📬 | Dir. Corresp. | 🟢 | RW | A0 | Dirección para recibir correspondencia postal |

**SCIM mapping:** `addresses.formatted` · `addresses.streetAddress` · `addresses.locality` · etc.
**OIDC mapping:** `address` (objeto con street_address/locality/region/postal_code/country)
**estructura value_data:** `{calle, numero, piso, barrio, ciudad, departamento, pais_code, codigo_postal, referencia, coordenadas_gps}`

---

### 10.12 Metadata CRUD — categoría `profesional` (6001-6032)

| tc | 🎨 | etiq | gdpr | mut | ial | hint_crud |
|---|---|---|---|---|---|---|
| 6001 | 🏷️ | Cód. Empleado | 🟢 | IM | SYS | Asignado por el sistema al registrar — no editable |
| 6002 | 💼 | Cargo | 🟢 | RW | A0 | Título del puesto de trabajo |
| 6003 | 💰 | Nivel Salarial | 🟠 | RW | L2 | Banda salarial — acceso restringido a RRHH |
| 6004 | 📄 | Tipo Contrato | 🟢 | RW | A0 | indefinido / plazo_fijo / eventual / honorarios |
| 6005 | 📅 | F. Ingreso | 🟢 | IM | A0 | Fecha de ingreso AAAA-MM-DD — no cambia |
| 6006 | 📤 | F. Egreso | 🟢 | RW | A0 | Fecha fin de relación laboral, si aplica |
| 6007 | 🎓 | Título Acad. | 🟢 | RW | L2 | Nombre oficial del título universitario |
| 6008 | 🏫 | Institución | 🟢 | RW | A0 | Universidad o institución que emitió el título |
| 6009 | 📅 | Año Titulación | 🟢 | RW | A0 | Año de obtención del título (4 dígitos) |
| 6010 | 📋 | N° Matrícula | 🟢 | RW | L2 | N° de matrícula en colegio profesional |
| 6011 | 🏛️ | Colegio Prof. | 🟢 | RW | A0 | Nombre del colegio o asociación profesional |
| 6012 | 🏆 | Certificación | 🟢 | RW | A0 | Nombre de la certificación obtenida |
| 6013 | ⏰ | Venc. Certif. | 🟢 | RW | A0 | Fecha de vencimiento de la certificación |
| 6014 | 🔬 | Especialidad | 🟢 | RW | A0 | Especialidad dentro de la profesión |
| 6015 | 🔬 | Sub-especialidad | 🟢 | RW | A0 | Sub-área de la especialidad |
| 6016 | 👥 | N° Empleados | 🟢 | RW | A0 | Total de empleados en el bDomain |
| 6017 | 🏭 | Sector CAEB | 🟢 | RW | A0 | Código CAEB de la actividad (SIN Bolivia) |
| 6018 | 📊 | Giro Comercial | 🟢 | RW | A0 | Descripción de la actividad económica principal |
| 6019 | 🕐 | Horario | 🟢 | RW | A0 | Ej: Lun-Vie 08:00-18:00 / Sáb 08:00-13:00 |
| 6020 | 💳 | Método Pago | 🟢 | RW | A0 | efectivo / tarjeta / transferencia / QR / cheque |
| 6021 | 🔄 | Turno | 🟢 | RW | A0 | mañana / tarde / noche / partido / rotativo |
| 6022 | 🔬 | ORCID | 🟢 | RW | A0 | ID ORCID · Ej: 0000-0001-2345-6789 |
| 6023 | 📰 | Publicación | 🟢 | RW | A0 | DOI · Ej: 10.1000/xyz123 |
| 6024 | ⭐ | Evaluación | 🟢 | RO | SYS | Resultado de evaluación — emitido por el sistema |
| 6025 | 🛠️ | Habilidad | 🟢 | RW | A0 | Skill técnica o funcional (ej: Python, Contabilidad) |
| 6026 | 🗣️ | Idioma Prof. | 🟢 | RW | A0 | BCP47 con nivel: es-BO:nativo / en-US:intermedio |
| 6027 | ⏱️ | Acceso Temporal | 🟢 | RW | A0 | Rango de fechas para acceso limitado |
| 6028 | 📚 | Grado Escolar | 🟢 | RW | A0 | Ej: 1ro Secundaria, 5to Primaria |
| 6029 | 🎓 | Institución Educ. | 🟢 | RW | A0 | Nombre del colegio o escuela actual |
| 6030 | 🏭 | Empresa Empl. | 🟢 | RW | A0 | Empresa que envía al contratista o visitante |
| 6031 | 🎯 | Motivo Visita | 🟢 | RW | A0 | entrega / mantenimiento / auditoria / inspeccion |
| 6032 | 🚗 | Placa Visita | 🟢 | RW | A0 | Placa del vehículo con que llegó el visitante |

**SCIM mapping:** `title` (6002) · `employeeNumber` (6001) · `department` (en extensión SCIM Enterprise)
**OIDC mapping:** ninguno estándar — usar namespace personalizado `sbos:cargo`, `sbos:departamento`

---

### 10.13 Metadata CRUD — categoría `financiero` (7001-7011)

| tc | 🎨 | etiq | gdpr | mut | ial | hint_crud |
|---|---|---|---|---|---|---|
| 7001 | 🏦 | Cuenta Bancaria | 🟠 | RW | L2 | N° de cuenta sin espacios — verificar con banco |
| 7002 | 🏦 | Banco | 🟢 | RW | A0 | Nombre completo de la entidad bancaria |
| 7003 | 💱 | Moneda Cuenta | 🟢 | RW | A0 | ISO 4217 · Ej: BOB, USD, EUR |
| 7004 | 🏥 | Tipo Seguro Med. | 🟡 | RW | A0 | CNS / COSSMIL / Caja / Privado / Ninguno |
| 7005 | 🪪 | N° Seguro Med. | 🟡 | RW | L2 | N° de afiliado al seguro médico — dato de salud |
| 7006 | 💳 | Línea Crédito | 🟠 | RW | L2 | Monto + moneda — acceso restringido finanzas |
| 7007 | 💰 | Capital Decl. | 🟠 | RW | L2 | Capital declarado ante el SIN — dato tributario |
| 7008 | 🏠 | Avalúo | 🟠 | RW | L2 | Avalúo del bien en moneda local |
| 7009 | 📋 | Folio Real | 🟢 | RW | A0 | N° de Folio Real en DDRR Bolivia |
| 7010 | 📄 | N° Póliza | 🟢 | RW | A0 | N° de póliza de seguro |
| 7011 | 📊 | Score Cred. | 🟠 | RO | SYS | Score calculado por entidad financiera externa |

**grupo_formulario:** `financiero` · **requiere_dpia:** true (7006, 7007, 7008)
**retencion_dias:** 3650 (10 años — obligación fiscal Bolivia Ley 843)

---

### 10.14 Metadata CRUD — categoría `dispositivo` · genérico (8001-8017)

| tc | 🎨 | etiq | gdpr | mut | ial | hint_crud |
|---|---|---|---|---|---|---|
| 8001 | 🖥️ | Nombre Disp. | 🟢 | RW | A0 | Nombre canónico · Ej: ATM-Sopocachi-01 |
| 8002 | 🏭 | Fabricante | 🟢 | RW | A0 | Nombre del fabricante · Ej: Siemens, ZKTeco |
| 8003 | 📋 | Modelo | 🟢 | RW | A0 | Modelo exacto del fabricante |
| 8004 | 🔢 | N° Serie | 🟢 | IM | A0 | Número de serie del fabricante — no cambia |
| 8005 | ⚙️ | Firmware | 🟢 | RW | SYS | Versión firmware actual en SEMVER |
| 8006 | 🔗 | MAC Address | 🟢 | IM | SYS | AA:BB:CC:DD:EE:FF — no cambia en producción |
| 8007 | 🌐 | IP Address | 🟢 | RW | SYS | IP actual del dispositivo |
| 8008 | 🔑 | Client ID | 🟢 | IM | SYS | OAuth2 Client ID — generado por bAuth al registrar |
| 8009 | 🎫 | Scopes OAuth2 | 🟢 | RW | SYS | Scopes separados por espacio |
| 8010 | 💻 | SO | 🟢 | RW | A0 | Nombre + versión del sistema operativo |
| 8011 | ✅ | PCI DSS | 🟢 | RW | L2 | ¿Cumple PCI DSS 4.0? Requiere evidencia |
| 8012 | 🔗 | IdP Externo | 🟢 | RW | A0 | URL o nombre del IdP externo federado |
| 8013 | 🆔 | Subject IdP | 🟢 | IM | SYS | Subject del IdP externo — inmutable |
| 8014 | 🧠 | Modelo IA | 🟢 | RW | A0 | Nombre del modelo IA · Ej: claude-sonnet-4-6 |
| 8015 | 🤖 | Proveedor IA | 🟢 | RW | A0 | Empresa proveedora · Anthropic, OpenAI, etc. |
| 8016 | 🎫 | Sesión IA | 🟢 | RO | SYS | Session ID de la sesión activa del agente |
| 8017 | 👁️ | Supervisión IA | 🟢 | RW | A0 | ninguna / auditoria / aprobacion_destructivos / siempre |

**grupo_formulario:** `tecnico` · **retencion_dias:** 1825 (5 años vida del dispositivo)

---

### 10.15 Metadata CRUD — `dispositivo` · biométrico (8100-8119)

| tc | 🎨 | etiq | gdpr | mut | ial | hint_crud |
|---|---|---|---|---|---|---|
| 8100 | 👆 | Tipo Biom. | 👆 | IM | A0 | huella_dactilar / iris / cara / vena_palma / multimodal |
| 8101 | 📊 | FAR | 👆 | RW | A0 | False Accept Rate · Ej: 0.0001% (hoja de datos fab.) |
| 8102 | 📊 | FRR | 👆 | RW | A0 | False Rejection Rate · Ej: 0.5% |
| 8103 | 🛡️ | SAR | 👆 | RW | A0 | Spoofing Accept Rate — estándar ISO/IEC 30107 |
| 8104 | 🔬 | Resolución | 👆 | RW | A0 | DPI para huellas · Ej: 500 DPI |
| 8105 | 💾 | Cap. Templates | 👆 | RW | A0 | N° máximo de plantillas almacenables en el equipo |
| 8106 | ⚙️ | Modo Op. | 👆 | RW | A0 | verificacion_1a1 / identificacion_1aN / dual_modo |
| 8107 | 🔐 | Certif. FIDO2 | 👆 | RW | L2 | Nivel FIDO2 certificado · Ej: FIDO2 Level 2 |
| 8108 | 🛡️ | Nivel PAD | 👆 | RW | L2 | ISO 30107 Nivel 1 / 2 / 3 (anti-suplantación) |
| 8109 | ⚡ | T. Respuesta | 👆 | RW | A0 | Milisegundos promedio de verificación · Ej: 350 |
| 8110 | 🌡️ | Temp. Op. | 🟢 | RW | A0 | Rango operativo · Ej: -10°C a +50°C |
| 8111 | 🌧️ | Grado IP | 🟢 | RW | A0 | IP65 / IP67 / IP68 según IEC 60529 |
| 8112 | 🔌 | Conector | 🟢 | RW | A0 | TCP_IP / RS485 / Wiegand / OSDP / USB / BLE |
| 8113 | 📏 | Dist. Captura | 👆 | RW | A0 | Distancia máxima de captura en cm |
| 8114 | 💡 | NIR | 👆 | RW | A0 | ¿Usa iluminación Near InfraRed? (true/false) |
| 8115 | 📐 | Ángulo Visión | 👆 | RW | A0 | Campo de visión en grados (cámaras biométricas) |
| 8116 | 📏 | Dist. Detección | 👆 | RW | A0 | Rango de detección en metros · Ej: 0.3-5m |
| 8117 | 👥 | Rostros Sim. | 👆 | RW | A0 | N° de rostros procesados en paralelo |
| 8118 | 📜 | Certif. GDPR | 👆 | RW | L2 | Certificación de conformidad GDPR biometría facial |
| 8119 | 👁️ | Liveness | 👆 | RW | A0 | basico / avanzado / ISO_30107_3D |

**requiere_dpia:** true (todos — biométrico es Art. 9 GDPR) · **retencion_dias:** 365

---

### 10.16 Metadata CRUD — `dispositivo` · RFID, PIN, cerradura (8120-8137)

| tc | 🎨 | etiq | gdpr | mut | ial | hint_crud |
|---|---|---|---|---|---|---|
| 8120 | 💳 | Tipo Tarjeta | 🟢 | IM | A0 | RFID_125kHz / RFID_13.56MHz / NFC / DESFire |
| 8121 | 📡 | Frec. RFID | 🟢 | IM | A0 | LF_125kHz / HF_13.56MHz / UHF_868MHz |
| 8122 | 🔢 | Wiegand | 🟢 | RW | A0 | W26 / W34 / W37 / ABA_Track2 / sin_wiegand |
| 8123 | 🔌 | Protocolo Acc. | 🟢 | RW | A0 | OSDP_v2 / Wiegand / RS485 / TCP_IP |
| 8124 | 📏 | Rango Lectura | 🟢 | RW | A0 | Distancia máxima de lectura en cm |
| 8125 | 🔒 | Cifrado Tarj. | 🟢 | RW | A0 | ¿Cifra comunicación con la tarjeta? (true/false) |
| 8126 | ⌨️ | Tipo Keypad | 🟢 | IM | A0 | fisico / tactil / virtual_screen |
| 8127 | 🔢 | Long. PIN | 🟢 | RW | A0 | Rango · Ej: 4-8 dígitos |
| 8128 | 🕵️ | Anti-espionaje | 🟢 | RW | A0 | ¿Protector visual + scramble de teclas? (true/false) |
| 8129 | 🚫 | Intentos PIN | 🟢 | RW | A0 | N° máximo de intentos antes de bloqueo |
| 8130 | 🔐 | Certif. PCI PIN | 🟢 | RW | L2 | PCI PTS SRED nivel certificado |
| 8131 | 🔐 | Tipo Cerradura | 🟢 | IM | A0 | electromagnetica / electromecanica / solenoide |
| 8132 | 💪 | Retención kg | 🟢 | RW | A0 | Fuerza de retención en kg (cierres magnéticos) |
| 8133 | 🗝️ | Modos Apertura | 🟢 | RW | A0 | rfid / pin / app_bt / app_wifi / llave / biometrico |
| 8134 | ⏱️ | T. Apertura s | 🟢 | RW | A0 | Segundos que permanece abierta · Ej: 5.0 |
| 8135 | 📋 | Log Local | 🟢 | RW | A0 | N° de eventos almacenados localmente |
| 8136 | 🔋 | Batería Backup | 🟢 | RW | A0 | Horas de respaldo con batería |
| 8137 | 🚨 | Failsafe | 🟢 | IM | A0 | fail_secure (cierra sin energía) / fail_safe (abre) |

---

### 10.17 Metadata CRUD — `dispositivo` · IoT/sensores (8140-8148)

| tc | 🎨 | etiq | gdpr | mut | ial | hint_crud |
|---|---|---|---|---|---|---|
| 8140 | 🌡️ | Tipo Sensor | 🟢 | IM | A0 | temperatura / humedad / gas_co2 / movimiento / energia |
| 8141 | 📊 | Rango Med. | 🟢 | RW | A0 | Ej: -40°C a +85°C · según hoja de datos |
| 8142 | 🔬 | Precisión | 🟢 | RW | A0 | Ej: ±0.5°C · según hoja de datos del fabricante |
| 8143 | 📐 | Unidad | 🟢 | IM | A0 | °C / % / ppm / kWh / lux / m/s |
| 8144 | ⏱️ | Intervalo s | 🟢 | RW | A0 | Segundos entre muestras · Ej: 60 |
| 8145 | 📡 | Protocolo IoT | 🟢 | RW | A0 | MQTT / CoAP / Modbus / OPC_UA / LoRaWAN |
| 8146 | 🔗 | Gateway ID | 🟢 | RW | SYS | UUID del gateway al que está conectado |
| 8147 | 📊 | Último Valor | 🟢 | RO | SYS | Última lectura: {valor, timestamp, calidad} — auto |
| 8148 | 🔔 | Alerta Umbral | 🟢 | RW | A0 | {min, max, accion} · umbral de alerta activa |

---

### 10.18 Metadata CRUD — `dispositivo` · PLC industrial, médico, ATM, POS, cámara (8150-8213)

| tc | 🎨 | etiq | gdpr | mut | ial | hint_crud |
|---|---|---|---|---|---|---|
| 8150 | ⚙️ | Tipo PLC | 🟢 | IM | A0 | S7_1500 / CompactLogix / Modicon / CX-One |
| 8151 | 🔌 | Entradas DI | 🟢 | RW | A0 | N° de entradas digitales |
| 8152 | 🔌 | Salidas DO | 🟢 | RW | A0 | N° de salidas digitales |
| 8153 | 📊 | Entradas AI | 🟢 | RW | A0 | N° de entradas analógicas |
| 8154 | ⚡ | Ciclo Scan ms | 🟢 | RW | A0 | Tiempo de ciclo de scan en milisegundos |
| 8155 | 🛡️ | Nivel SIL | 🟢 | RW | L2 | SIL 1 / 2 / 3 / 4 — certificado IEC 61508 |
| 8156 | 🌐 | Red Industrial | 🟢 | RW | A0 | PROFINET / EtherNet_IP / Modbus_TCP |
| 8157 | 📡 | Protocolo SCADA | 🟢 | RW | A0 | OPC_UA / Modbus / DNP3 / IEC104 |
| 8158 | ⚙️ | Firmware PLC | 🟢 | RW | A0 | Versión de firmware del PLC |
| 8159 | 📜 | Certif. CE/UL | 🟢 | RW | L2 | Ej: CE IEC 61131-2 — requiere documento |
| 8170 | 🏥 | Clase FDA | 🟢 | IM | L3 | I / II / III — requiere documentación oficial |
| 8171 | 🔢 | UDI Device | 🟢 | IM | L3 | Unique Device Identifier según FDA UDI |
| 8172 | 📜 | ISO 13485 | 🟢 | RW | L2 | N° certificación ISO 13485 del fabricante |
| 8173 | 📡 | Protocolo Med. | 🟢 | RW | A0 | HL7_FHIR_R4 / DICOM / HL7_v2 / IHE |
| 8174 | 🧪 | Esterilización | 🟢 | RW | A0 | esteril / no_esteril / reutilizable_esteril |
| 8175 | 📅 | Calibración | 🟢 | RW | A0 | Fecha última calibración AAAA-MM-DD |
| 8176 | ⏰ | Prox. Calibr. | 🟢 | RW | A0 | Fecha de próxima calibración obligatoria |
| 8177 | 🏥 | FHIR Resource | 🟡 | RW | L3 | Tipo de recurso HL7 FHIR R4 que genera |
| 8180 | 💰 | N° Cassettes | 🟢 | RW | A0 | N° de cassettes de billetes instalados · Ej: 4 |
| 8181 | 💵 | Cap. Billetes | 🟢 | RW | A0 | Billetes por cassette · Ej: 2000 |
| 8182 | 🔐 | PCI PTS | 🟢 | RW | L2 | Versión PCI PTS aprobada · Ej: PCI PTS 6.0 |
| 8183 | 🔒 | P2PE | 🟢 | RW | L2 | Versión PCI P2PE · Ej: v3.0 |
| 8184 | 💻 | XFS Level | 🟢 | RW | A0 | Versión XFS soportada · Ej: XFS 3.30 |
| 8185 | 🌐 | Red ATM | 🟢 | RW | A0 | TCP_IP_TLS1_3 / ADSL / Fibra / 4G |
| 8186 | 💻 | SO Base | 🟢 | RW | A0 | Sistema operativo del ATM |
| 8187 | 🔐 | HDD Cifrado | 🟢 | RW | L2 | {algoritmo, tpm} — AES-256 + TPM 2.0 |
| 8188 | 🛡️ | Anti-skimming | 🟢 | RW | A0 | ¿Tiene sensor anti-copia? (true/false) |
| 8190 | 💳 | Tipo POS | 🟢 | IM | A0 | fijo / movil / softpos / integrado |
| 8191 | ✅ | EMV Contact | 🟢 | RW | A0 | ¿Acepta chip EMV? (true/false) |
| 8192 | 📲 | EMV Contactless | 🟢 | RW | A0 | ¿Acepta pago sin contacto? (true/false) |
| 8193 | 🔐 | PCI SRED | 🟢 | RW | L2 | Certificación PCI PTS SRED del terminal |
| 8194 | 📟 | Pantalla Cliente | 🟢 | RW | A0 | ¿Tiene display para el cliente? (true/false) |
| 8195 | 🖨️ | Impresora | 🟢 | RW | A0 | ¿Tiene impresora integrada? (true/false) |
| 8200 | 📷 | Tipo Cámara | 🟢 | IM | A0 | fija_interior / fija_exterior / ptz / fisheye |
| 8201 | 📺 | Resolución Vid. | 🟢 | RW | A0 | Ej: 1920x1080, 3840x2160 (4K) |
| 8202 | 🎬 | FPS | 🟢 | RW | A0 | Cuadros por segundo máximos · Ej: 30 |
| 8203 | 🌙 | Vis. Nocturna m | 🟢 | RW | A0 | Alcance de visión nocturna en metros |
| 8204 | 📐 | Ángulo Visión | 🟢 | RW | A0 | Ángulo horizontal en grados |
| 8205 | 💾 | Compresión | 🟢 | RW | A0 | H.264 / H.265 / MJPEG |
| 8206 | 🗄️ | Almacen. días | 🟢 | RW | A0 | Días de video almacenados localmente o en NVR |
| 8207 | 🧠 | Analytics IA | 🟢 | RW | A0 | {tipos:[facial,lpr,counting], motor:...} |
| 8210 | ⚡ | Clase Precisión | 🟢 | IM | A0 | IEC 62053: 0.2S / 0.5S / 1 / 2 |
| 8211 | 📡 | Protocolo Med. | 🟢 | RW | A0 | DLMS_COSEM / ANSI_C12 / IEC_62056 / PRIME |
| 8212 | ⏱️ | Interv. Lectura | 🟢 | RW | A0 | Minutos entre lecturas del medidor |
| 8213 | 🔌 | Corte Remoto | 🟢 | RW | A0 | ¿Permite corte/reconexión remota? (true/false) |
| 8220 | 🌐 | Tipo Equipo Red | 🟢 | IM | A0 | firewall / switch_gestionado / utm / waf |
| 8221 | ⚡ | Throughput Gbps | 🟢 | RW | A0 | Rendimiento máximo en Gbps |
| 8222 | 🔌 | N° Puertos | 🟢 | RW | A0 | Número de puertos de red |
| 8223 | 🔐 | CC EAL | 🟢 | RW | L2 | Common Criteria EAL · Ej: CC EAL4+ |
| 8224 | 🔒 | VPN Soporte | 🟢 | RW | A0 | ¿Soporta VPN? (true/false) |
| 8225 | 🛡️ | IDS/IPS | 🟢 | RW | A0 | ¿Incluye detección/prevención de intrusos? |
| 8230 | 🔐 | Tipo HSM | 🟢 | IM | A0 | red / usb / embebido / cloud_hsm |
| 8231 | 🔐 | FIPS Nivel | 🟢 | RW | L2 | FIPS 140 Level 1 / 2 / 3 / 4 |
| 8232 | ⚡ | Crypto TPS | 🟢 | RW | A0 | Transacciones criptográficas por segundo |
| 8233 | 🔑 | Algoritmos | 🟢 | RW | A0 | RSA / ECDSA / AES-256 / Ed25519 / SHA-3 |
| 8234 | 📜 | PCI HSM | 🟢 | RW | L2 | Certificación PCI HSM del módulo |
| 8235 | 🛡️ | Tamper Evident | 🟢 | RW | A0 | ¿Tiene protección anti-manipulación física? |

---

### 10.19 Metadata CRUD — categoría `vehiculo` (9100-9114)

| tc | 🎨 | etiq | gdpr | mut | ial | hint_crud |
|---|---|---|---|---|---|---|
| 9100 | 🚗 | Placa | 🟢 | RW | L2 | Formato local · Ej: 3456-TLP (Bolivia) |
| 9101 | 🔢 | VIN | 🟢 | IM | A0 | 17 caracteres ISO 3779 — no se modifica |
| 9102 | 🚌 | Tipo Vehículo | 🟢 | IM | A0 | sedan / suv / pickup / camion / furgon / moto |
| 9103 | 🏭 | Marca | 🟢 | IM | A0 | Toyota / Ford / Chevrolet / Nissan / etc. |
| 9104 | 📋 | Modelo | 🟢 | IM | A0 | Nombre del modelo exacto del fabricante |
| 9105 | 📅 | Año Fabric. | 🟢 | IM | A0 | Año de fabricación · 4 dígitos |
| 9106 | 🎨 | Color | 🟢 | RW | A0 | Color actual del vehículo |
| 9107 | 💺 | N° Asientos | 🟢 | IM | A0 | Capacidad de asientos incluido conductor |
| 9108 | 📄 | SOAT N° | 🟢 | RW | A0 | N° de póliza SOAT vigente |
| 9109 | ⏰ | SOAT Vence | 🟢 | RW | A0 | Fecha vencimiento SOAT · AAAA-MM-DD |
| 9110 | 🛡️ | Póliza Seguro | 🟢 | RW | A0 | N° de póliza de seguro adicional |
| 9111 | 👤 | Propietario ID | 🟢 | RW | A0 | UUID del propietario (tenant/bdomain/actor) |
| 9112 | 👨‍✈️ | Conductor ID | 🟢 | RW | A0 | UUID del conductor asignado actualmente |
| 9113 | 🚁 | Tipo Dron | 🟢 | IM | A0 | multirotor / ala_fija / hibrido / nano |
| 9114 | 📜 | Certif. BVLOS | 🟢 | RW | L3 | Certificación para vuelo más allá de la vista |

---

### 10.20 Metadata CRUD — categoría `software` (9200-9284)

| tc | 🎨 | etiq | gdpr | mut | ial | hint_crud |
|---|---|---|---|---|---|---|
| 9200 | ⚙️ | Nombre Servicio | 🟢 | IM | A0 | Nombre canónico del daemon · Ej: bauth |
| 9201 | 🔑 | Hash Binario | 🟢 | RO | SYS | SHA256 del binario — actualizado en cada deploy |
| 9202 | 🔌 | Socket Path | 🟢 | IM | A0 | Ruta Unix socket · Ej: /run/bos/bauth.sock |
| 9203 | 🌐 | Puerto | 🟢 | IM | A0 | Puerto TCP o 0 si usa Unix socket |
| 9204 | 📋 | SBOM | 🟢 | RW | SYS | URL/hash del Software Bill of Materials SPDX 2.3 |
| 9205 | 🔍 | CVE Scan Fecha | 🟢 | RO | SYS | Fecha del último escaneo de vulnerabilidades |
| 9206 | 🚨 | CVE Score Max | 🟢 | RO | SYS | Score CVSS v3.1 máximo sin parchear |
| 9210 | 🌐 | Tipo Gateway | 🟢 | IM | A0 | api_gateway / service_mesh / reverse_proxy / waf |
| 9211 | 🗺️ | Rutas Config. | 🟢 | RW | A0 | N° de rutas/endpoints configurados |
| 9212 | 🔌 | Plugins | 🟢 | RW | A0 | Plugins activos separados por coma |
| 9213 | ⚡ | RPS Max | 🟢 | RW | A0 | Requests por segundo máximos soportados |
| 9220 | 📨 | Tipo Broker | 🟢 | IM | A0 | kafka / rabbitmq / redis_streams / nats |
| 9221 | 📋 | N° Topics | 🟢 | RW | A0 | N° de topics/queues configurados |
| 9222 | ⏱️ | Retención días | 🟢 | RW | A0 | Días de retención de mensajes en el broker |
| 9223 | 🔄 | Replicación | 🟢 | RW | A0 | Factor de replicación · Ej: 3 |
| 9224 | 🔒 | Auth. SASL | 🟢 | RW | A0 | PLAIN / SCRAM_SHA256 / OAUTHBEARER |
| 9230 | 🤖 | Tipo Bot | 🟢 | IM | A0 | cron_job / rpa_bot / etl_pipeline / report_generator |
| 9231 | ⏰ | Cron Schedule | 🟢 | RW | A0 | Expresión cron · Ej: 0 2 * * * (02:00 diario) |
| 9232 | ⏱️ | T. Ejecución s | 🟢 | RO | SYS | Tiempo promedio en segundos — medido por el sistema |
| 9233 | 👤 | Propietario | 🟢 | RW | A0 | UUID del HUMAN responsable del bot |
| 9234 | 🤖 | Plataforma RPA | 🟢 | RW | A0 | uipath / automation_anywhere / blueprism |
| 9235 | 🎯 | Sistema Objetivo | 🟢 | RW | A0 | Sistema que automatiza el bot |
| 9236 | 🔐 | Cred. Vault | 🟢 | WO | A0 | Ruta en Vault — NUNCA el valor real de la credencial |
| 9240 | 🔗 | Tipo IdP | 🟢 | IM | A0 | oidc / saml2 / ldap / active_directory / eidas_wallet |
| 9241 | ✅ | Email Verif. IdP | 🟢 | RO | SYS | ¿El IdP confirmó el email? — inmutable del IdP |
| 9242 | 🛡️ | ACR | 🟢 | RO | SYS | Nivel de autenticación reportado por el IdP externo |
| 9243 | 🔑 | AMR | 🟢 | RO | SYS | Métodos usados en el IdP · Ej: pwd mfa |
| 9250 | 🇪🇺 | Nivel eIDAS | 🟢 | RO | SYS | low / substantial / high — eIDAS Art. 8 |
| 9251 | 🔐 | eIDAS PID Hash | 🟢 | RO | SYS | Hash del PID — nunca el valor original |
| 9252 | 📋 | LDAP DN | 🟢 | IM | SYS | Distinguished Name · inmutable en producción |
| 9253 | 🆔 | LDAP SID | 🟢 | IM | SYS | Security Identifier AD — nunca cambia |
| 9270 | 🧠 | Modelo IA | 🟢 | RW | A0 | ID del modelo · Ej: claude-sonnet-4-6-20250514 |
| 9271 | 📊 | Ctx. Tokens | 🟢 | RO | SYS | Tokens de contexto máximo — del proveedor |
| 9272 | 🛠️ | Tool Access | 🟢 | RW | A0 | Herramientas habilitadas · Ej: Read,Write,Bash |
| 9273 | 📁 | Project Scope | 🟢 | RW | A0 | Ruta del proyecto · Ej: SBOS/BauthAgent |
| 9274 | 👁️ | Aprobación HITL | 🟢 | RW | A0 | nunca / para_destructivos / siempre |
| 9280 | 🤖 | Tipo Modelo ML | 🟢 | IM | A0 | clasificacion / regresion / anomalias / nlp / vision |
| 9281 | ⚙️ | Framework ML | 🟢 | RW | A0 | tensorflow / pytorch / sklearn / xgboost / onnx |
| 9282 | 📊 | Precisión Modelo | 🟢 | RO | SYS | Accuracy / F1 en producción — medido en runtime |
| 9283 | 📡 | Drift Monitor | 🟢 | RW | A0 | ¿Monitorea data drift activamente? (true/false) |
| 9284 | ⚡ | Latencia P99 ms | 🟢 | RO | SYS | Latencia P99 en producción — medido en runtime |

---

### 10.21 Metadata CRUD — categoría `suscripcion` + `facturacion` (10001-11006)

| tc | 🎨 | etiq | gdpr | mut | ial | hint_crud |
|---|---|---|---|---|---|---|
| 10001 | 📋 | Plan | 🟢 | RW | SYS | free / starter / professional / enterprise / custom |
| 10002 | 🏢 | Máx. bDomains | 🟢 | RW | SYS | Límite de bDomains — asignado por el plan |
| 10003 | 👥 | Máx. Usuarios | 🟢 | RW | SYS | Límite de usuarios activos — asignado por el plan |
| 10004 | 📅 | Inicio Suscr. | 🟢 | IM | SYS | Fecha de inicio de la suscripción — no cambia |
| 10005 | ⏰ | Venc. Suscr. | 🟢 | RW | SYS | Fecha de vencimiento — actualizable en renovación |
| 10006 | 🎧 | Nivel Soporte | 🟢 | RW | A0 | basico / estandar / prioritario / dedicado |
| 11001 | 🧾 | Modalidad Factur. | 🟢 | RW | A0 | propio / tercero / holding_centralizado / exento |
| 11002 | 🏛️ | NIT Facturador | 🟢 | RW | L2 | NIT del tercero que factura — verificar con SIN |
| 11003 | 🔑 | Auth. SFV | 🟢 | RW | L2 | Código de autorización SFV del SIN Bolivia |
| 11004 | 📊 | Régimen Trib. | 🟢 | RW | A0 | simplificado / general / especial / exento |
| 11005 | 💱 | Moneda Factur. | 🟢 | RW | A0 | ISO 4217 · Ej: BOB, USD |
| 11006 | 📜 | Resoluc. SIN | 🟢 | RW | L2 | N° de resolución normativa del SIN Bolivia |

---

### 10.22 Metadata CRUD — tipos nuevos: médico, educación, seguridad (9010-9014)

| tc | 🎨 | etiq | gdpr | mut | ial | hint_crud |
|---|---|---|---|---|---|---|
| 9010 | 📋 | Matrí. Médica | 🟢 | RW | L3 | {numero, colegio, vigencia} — verificar col. médico |
| 9011 | 🔬 | Área Médica | 🟡 | RW | L3 | {areas:[...], certif_date, entidad} — habilitaciones |
| 9013 | 📝 | Consent. Tutor | 🟡 | RW | L2 | {tutor_id, fecha, tipo, doc} — obligatorio menores |
| 9014 | 🚦 | Zona Acceso | 🟢 | RW | A0 | {zonas:[...], valido_hasta, horario} |

---

### 10.23 Metadata CRUD — válvula de escape (9998-9999)

| tc | 🎨 | etiq | gdpr | mut | ial | hint_crud |
|---|---|---|---|---|---|---|
| 9998 | 🔧 | Ext. Texto | 🟢 | RW | A0 | Atributo no catalogado — usar ext_tipo_key descriptivo |
| 9999 | 🔧 | Ext. JSONB | 🟢 | RW | A0 | Atributo estructurado no catalogado — ver §8.5 formato |

---

### 10.24 Resumen de grupos de formulario por actor.tipo

| grupo_formulario | Actor.tipos que lo usan | Tipos agrupados |
|---|---|---|
| `datos_basicos` | HUMAN | 1001-1013, 1101-1113 |
| `contacto` | HUMAN, tenant, bdomain | 2001-2010, 2101-2109, 2201-2209 |
| `documentos` | HUMAN | 3001-3028, 3101-3120 |
| `profesional` | HUMAN, bdomain | 6001-6032 |
| `financiero` | HUMAN, bdomain, tenant | 7001-7011, 11001-11006 |
| `tecnico` | DEVICE, SERVICE, BOT | 8001-8235, 9200-9284 |
| `seguridad` | todos | 9013-9014, atom_read/write |
| `suscripcion` | tenant | 10001-10006 |

---

---

## 11. Prueba de escritorio — `idn_tipo_catalogo` como biblioteca jerárquica unificada

### 11.1 El problema que motiva el cambio

Las §10 actuales son 20 tablas de documentación separadas. Eso mismo ocurriría en la
base de datos si cada subcategoría tuviera su propia tabla. La lección de `cfg_policy_library`
fue exactamente esta: 36 JSONs + 25 tablas `ath_*` → 1 tabla con árbol ltree.

La pregunta de esta prueba: **¿puede `idn_tipo_atributo` unificarse en una sola tabla
jerárquica con el mismo patrón?**

---

### 11.2 Analogía directa con `cfg_policy_library`

```
cfg_policy_library                      idn_tipo_catalogo (propuesta)
──────────────────────────────────────  ──────────────────────────────────────
nivel  FRAMEWORK                        nivel  BIBLIOTECA
nivel  DOMAIN                           nivel  CATEGORIA
nivel  POLICY_SET                       nivel  SUBCATEGORIA
nivel  POLICY                           nivel  SUB_SUBCATEGORIA  ← solo en dispositivo
nivel  RULE                             nivel  TIPO  (hoja)
nivel  PROPERTY  (hoja)

node_type  section | group | policy | config
                                        node_type  root | grupo | tipo

path  ltree  (índice GiST)             path  ltree  (mismo índice)
9,874 nodos totales                     ~384 nodos totales (más pequeño, mismo patrón)

FK desde cfg_tenant_config              FK desde idn_atributo
  → policy_library.id                    → idn_tipo_catalogo.tipo_code
```

**Diferencia clave:** en `cfg_policy_library` la hoja (PROPERTY) almacena el tipo del
valor y un default. En `idn_tipo_catalogo` la hoja (TIPO) almacena las reglas de
formato, validación y acceso. El valor real siempre vive en `idn_atributo`.

---

### 11.3 Árbol completo — 4 niveles, ~384 nodos

```
idn                                                      BIBLIOTECA   (1 nodo)
├── personal                                             CATEGORIA
│   ├── nombre                                           SUBCATEGORIA
│   │   ├── primer_nombre             tc=1001            TIPO
│   │   ├── segundo_nombre            tc=1002            TIPO
│   │   ├── nombre_preferido          tc=1008            TIPO
│   │   └── nombre_legal_completo     tc=1009            TIPO  (+ 7 más)
│   └── biografico                                       SUBCATEGORIA
│       ├── fecha_nacimiento          tc=1101            TIPO
│       ├── genero                    tc=1102            TIPO  ← GDPR Art.9 🟡
│       ├── tipo_sangre               tc=1104            TIPO  ← GDPR Art.9 🟡
│       └── tutor_legal               tc=1112            TIPO  (+ 9 más)
│
├── contacto                                             CATEGORIA
│   ├── telefono                                         SUBCATEGORIA
│   │   ├── telefono_movil            tc=2001            TIPO
│   │   ├── whatsapp                  tc=2007            TIPO
│   │   └── signal                    tc=2009            TIPO  (+ 7 más)
│   ├── email                                            SUBCATEGORIA
│   │   ├── email_personal            tc=2101            TIPO
│   │   └── email_recuperacion        tc=2106            TIPO  (+ 7 más)
│   └── red_social                                       SUBCATEGORIA
│       ├── linkedin                  tc=2201            TIPO
│       └── sitio_web                 tc=2208            TIPO  (+ 7 más)
│
├── documento                                            CATEGORIA
│   ├── identidad                                        SUBCATEGORIA
│   │   ├── ci_bo                     tc=3001            TIPO
│   │   ├── pasaporte                 tc=3013            TIPO
│   │   └── did_w3c                   tc=3023            TIPO  (+ 25 más)
│   └── tributario                                       SUBCATEGORIA
│       ├── nit_bo                    tc=3101            TIPO
│       └── vat_eu                    tc=3108            TIPO  (+ 18 más)
│
├── ubicacion                                            CATEGORIA
│   └── direccion                                        SUBCATEGORIA
│       ├── dir_fiscal                tc=4001            TIPO
│       └── dir_correspon             tc=4005            TIPO  (+ 3 más)
│
├── profesional                                          CATEGORIA
│   ├── empleo                                           SUBCATEGORIA
│   │   ├── cargo                     tc=6002            TIPO
│   │   ├── fecha_ingreso             tc=6005            TIPO
│   │   └── habilidad                 tc=6025            TIPO  (+ 24 más)
│   ├── educacion                                        SUBCATEGORIA
│   │   ├── grado_escolar             tc=6028            TIPO
│   │   └── institucion_educativa     tc=6029            TIPO
│   └── visita                                           SUBCATEGORIA
│       ├── empresa_empleadora        tc=6030            TIPO
│       ├── motivo_visita             tc=6031            TIPO
│       └── vehiculo_placa_visita     tc=6032            TIPO
│
├── medico                                               CATEGORIA  ← antes disperso
│   ├── habilitacion_prof                                SUBCATEGORIA
│   │   ├── matricula_medica          tc=9010            TIPO
│   │   └── area_medica_habilitada    tc=9011            TIPO
│   └── consentimiento                                   SUBCATEGORIA
│       ├── consentimiento_tutor      tc=9013            TIPO
│       └── zona_acceso_permitida     tc=9014            TIPO
│
├── financiero                                           CATEGORIA
│   └── bancario                                         SUBCATEGORIA
│       ├── cuenta_bancaria           tc=7001            TIPO
│       ├── scoring                   tc=7011            TIPO  (+ 9 más)
│       └── [11001-11006 facturacion]                    TIPO  ← FUSIÓN (ver §11.7)
│
├── dispositivo                                          CATEGORIA
│   ├── generico                                         SUBCATEGORIA
│   │   ├── nombre_dispositivo        tc=8001            TIPO
│   │   └── supervision_ia            tc=8017            TIPO  (+ 15 más)
│   ├── biometrico                                       SUBCATEGORIA
│   │   ├── tipo_biometrico           tc=8100            TIPO  ← gdpr 👆
│   │   └── liveness_detection        tc=8119            TIPO  (+ 18 más)
│   ├── acceso                                           SUBCATEGORIA
│   │   ├── rfid                                         SUB_SUBCATEGORIA
│   │   │   ├── tipo_tarjeta          tc=8120            TIPO
│   │   │   └── cifrado_tarjeta       tc=8125            TIPO  (+ 4 más)
│   │   ├── pin                                          SUB_SUBCATEGORIA
│   │   │   ├── tipo_keypad           tc=8126            TIPO
│   │   │   └── certif_pci_pin        tc=8130            TIPO  (+ 3 más)
│   │   └── cerradura                                    SUB_SUBCATEGORIA
│   │       ├── tipo_cerradura        tc=8131            TIPO
│   │       └── failsafe_modo         tc=8137            TIPO  (+ 5 más)
│   ├── iot_sensor                                       SUBCATEGORIA
│   │   ├── tipo_sensor               tc=8140            TIPO
│   │   └── alerta_umbral             tc=8148            TIPO  (+ 6 más)
│   ├── industrial                                       SUBCATEGORIA
│   │   ├── tipo_plc                  tc=8150            TIPO
│   │   └── certif_ce                 tc=8159            TIPO  (+ 8 más)
│   ├── medico_disp                                      SUBCATEGORIA
│   │   ├── clase_fda                 tc=8170            TIPO  ← gdpr 🟡
│   │   └── data_hl7_fhir             tc=8177            TIPO  (+ 6 más)
│   ├── atm                                              SUBCATEGORIA
│   │   ├── num_cassettes             tc=8180            TIPO
│   │   └── anticopy_sensor           tc=8188            TIPO  (+ 7 más)
│   ├── pos                                              SUBCATEGORIA
│   │   └── [8190-8195]               tc=8190-8195       TIPO  (6 tipos)
│   ├── camara                                           SUBCATEGORIA
│   │   └── [8200-8207]               tc=8200-8207       TIPO  (8 tipos)
│   ├── medidor                                          SUBCATEGORIA
│   │   └── [8210-8213]               tc=8210-8213       TIPO  (4 tipos)
│   ├── red_seguridad                                    SUBCATEGORIA
│   │   └── [8220-8225]               tc=8220-8225       TIPO  (6 tipos)
│   └── hsm                                              SUBCATEGORIA
│       └── [8230-8235]               tc=8230-8235       TIPO  (6 tipos)
│
├── vehiculo                                             CATEGORIA
│   ├── terrestre                                        SUBCATEGORIA
│   │   ├── placa_vehiculo            tc=9100            TIPO
│   │   └── conductor_asignado_id     tc=9112            TIPO  (+ 11 más)
│   └── aereo                                            SUBCATEGORIA
│       ├── tipo_dron                 tc=9113            TIPO
│       └── certif_bvlos              tc=9114            TIPO
│
├── software                                             CATEGORIA
│   ├── servicio_daemon                                  SUBCATEGORIA
│   │   └── [9200-9206]               tc=9200-9206       TIPO  (7 tipos)
│   ├── api_gateway                                      SUBCATEGORIA
│   │   └── [9210-9213]               tc=9210-9213       TIPO  (4 tipos)
│   ├── message_broker                                   SUBCATEGORIA
│   │   └── [9220-9224]               tc=9220-9224       TIPO  (5 tipos)
│   ├── bot_automatizado                                 SUBCATEGORIA
│   │   └── [9230-9236]               tc=9230-9236       TIPO  (7 tipos)
│   ├── identidad_federada                               SUBCATEGORIA
│   │   ├── idp_tipo                  tc=9240            TIPO
│   │   └── ldap_sid                  tc=9253            TIPO  (+ 12 más)
│   └── agente_ia                                        SUBCATEGORIA
│       └── [9270-9284]               tc=9270-9284       TIPO  (9 tipos)
│
├── suscripcion                                          CATEGORIA
│   └── plan                                             SUBCATEGORIA
│       └── [10001-10006]             tc=10001-10006     TIPO  (6 tipos)
│
└── extension                                            CATEGORIA
    └── libre                                            SUBCATEGORIA
        ├── atributo_extension_texto  tc=9998            TIPO
        └── atributo_extension_jsonb  tc=9999            TIPO
```

**Conteo de nodos:**
```
BIBLIOTECA        =   1
CATEGORIA         =  14  (personal, contacto, documento, ubicacion, profesional,
                           medico, financiero, dispositivo, vehiculo, software,
                           suscripcion, extension + facturacion fusionada en financiero)
SUBCATEGORIA      =  35
SUB_SUBCATEGORIA  =   3  (rfid, pin, cerradura — solo bajo dispositivo.acceso)
TIPO (hojas)      = ~328
──────────────────────────
Total             = ~381 nodos
```

---

### 11.4 DDL de la tabla unificada `idn_tipo_catalogo`

```sql
CREATE TABLE bauth.idn_tipo_catalogo (
    -- ─── Posición en el árbol ───────────────────────────────────────────────
    path           ltree        NOT NULL,    -- 'idn.dispositivo.biometrico.tipo_biometrico'
    nivel          TEXT         NOT NULL,    -- BIBLIOTECA|CATEGORIA|SUBCATEGORIA|
                                             -- SUB_SUBCATEGORIA|TIPO
    tipo_code      SMALLINT,                 -- solo en TIPO leaf (NULL en nodos internos)
    node_key       TEXT         NOT NULL,    -- último segmento del path (=tipo_key en hoja)

    -- ─── Identidad del nodo ─────────────────────────────────────────────────
    nombre_es      TEXT         NOT NULL,    -- nombre en español
    nombre_en      TEXT,                     -- nombre en inglés (API)
    descripcion    TEXT,

    -- ─── Solo en TIPO hoja (NULL en nodos internos) ─────────────────────────
    display_format    TEXT,           -- widget: ENUM|TEXT|DATE|E164|BOOLEAN|INTEGER|FLOAT
    default_value     TEXT,           -- valor por defecto (mismo patrón que cfg_policy_library)
    enum_options      TEXT[],         -- vocabulario controlado — GIN indexable (ENUM + TEXT con vocab)
    mask              TEXT,           -- patrón enmascarado UI: '+## (###) ###-####'
    placeholder       TEXT,           -- texto de ejemplo visible en campo vacío
    validation_policy JSONB           DEFAULT '{}'::jsonb,  -- regex, normalize, min/max
    atom_read        SMALLINT        REFERENCES bauth.privilege_atom(atom_code),
    atom_write       SMALLINT        REFERENCES bauth.privilege_atom(atom_code),
    atom_verify      SMALLINT        REFERENCES bauth.privilege_atom(atom_code),
    atom_export      SMALLINT        REFERENCES bauth.privilege_atom(atom_code),
    aplica_a         TEXT[]          DEFAULT '{}',
    es_multiple      BOOLEAN         DEFAULT true,
    es_verificable   BOOLEAN         DEFAULT false,
    es_sensible      BOOLEAN         DEFAULT false,
    muestra_enmascarado BOOLEAN      DEFAULT false,

    -- ─── Campos UI/CRUD nuevos §10 (también en nodos internos para agrupar) ─
    icono            TEXT,           -- emoji — aparece en TODOS los niveles
    etiqueta_corta   TEXT,           -- columna de tabla — solo en TIPO
    hint_crud        TEXT,           -- texto de ayuda — solo en TIPO
    grupo_formulario TEXT,           -- pestaña UI — en SUBCATEGORIA y TIPO
    orden_en_grupo   SMALLINT        DEFAULT 0,
    es_requerido     BOOLEAN         DEFAULT false,
    mutabilidad      TEXT            DEFAULT 'readWrite'
        CONSTRAINT ck_itc_mut CHECK (mutabilidad IN
            ('readWrite','readOnly','immutable','writeOnly')),
    unicidad         TEXT            DEFAULT 'none'
        CONSTRAINT ck_itc_uni CHECK (unicidad IN ('none','por_entidad','global')),
    gdpr_categoria   TEXT            DEFAULT 'ordinario'
        CONSTRAINT ck_itc_gdpr CHECK (gdpr_categoria IN (
            'ordinario','especial_art9','biometrico','financiero','anonimo')),
    requiere_dpia    BOOLEAN         DEFAULT false,
    retencion_dias   INT,
    ial_minimo       TEXT            DEFAULT 'autoafirmado'
        CONSTRAINT ck_itc_ial CHECK (ial_minimo IN (
            'autoafirmado','IAL1','IAL2','IAL3','sistema')),
    servicio_verificacion TEXT
        CONSTRAINT ck_itc_sv CHECK (servicio_verificacion IN (
            'ninguno','email_smtp','sms_otp','sin_bolivia',
            'segip_bolivia','adsib','banco','manual','fido2')),
    scim_name        TEXT,
    oidc_claim       TEXT,

    -- ─── Metadatos del nodo ─────────────────────────────────────────────────
    sort_order       SMALLINT        DEFAULT 0,
    is_active        BOOLEAN         NOT NULL DEFAULT true,
    standard_ref     TEXT,
    created_at       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_idn_tipo_catalogo  PRIMARY KEY (path),
    CONSTRAINT uk_itc_tipo_code      UNIQUE (tipo_code),   -- NULL ignored
    CONSTRAINT ck_itc_nivel          CHECK (nivel IN (
        'BIBLIOTECA','CATEGORIA','SUBCATEGORIA','SUB_SUBCATEGORIA','TIPO'))
);

-- Índice principal GiST para queries de árbol
CREATE INDEX ix_itc_path_gist  ON bauth.idn_tipo_catalogo USING GIST (path);
-- Índice B-tree para búsquedas exactas por tipo_code
CREATE INDEX ix_itc_tipo_code  ON bauth.idn_tipo_catalogo (tipo_code) WHERE tipo_code IS NOT NULL;
-- Índice para navegación por nivel
CREATE INDEX ix_itc_nivel      ON bauth.idn_tipo_catalogo (nivel, sort_order);
-- Índice GIN para búsqueda por vocabulario controlado (enum_options @> ARRAY[...])
CREATE INDEX ix_itc_enum_gin   ON bauth.idn_tipo_catalogo USING GIN (enum_options) WHERE enum_options IS NOT NULL;
```

---

### 11.5 Filas de muestra en los cuatro niveles

```sql
-- Columnas de posición: path, nivel, tipo_code, node_key,
--   nombre_es, nombre_en, descripcion,
--   display_format, default_value, enum_options, mask, placeholder, validation_policy,
--   atom_read, atom_write, atom_verify, atom_export,
--   aplica_a, es_multiple, es_verificable, es_sensible, muestra_enmascarado,
--   icono, etiqueta_corta, hint_crud, grupo_formulario, orden_en_grupo, es_requerido,
--   mutabilidad, unicidad, gdpr_categoria, requiere_dpia, retencion_dias, ial_minimo,
--   servicio_verificacion, scim_name, oidc_claim,
--   sort_order, is_active, standard_ref

-- BIBLIOTECA (raíz) — nodos internos: display_format/default_value/enum_options/mask/placeholder = NULL
('idn', 'BIBLIOTECA', NULL, 'idn',
 'Catálogo de Atributos de Identidad', 'Identity Attribute Catalog',
 'Biblioteca unificada de tipos de atributo — todos los actores y dominios',
 NULL, NULL, NULL, NULL, NULL, '{}', NULL, NULL, NULL, NULL,
 '{}', true, false, false, false,
 '📚', NULL, NULL, NULL, 0, false,
 'readOnly', 'none', 'ordinario', false, NULL, 'autoafirmado', NULL, NULL, NULL,
 0, true, NULL);

-- CATEGORIA (nivel 2)
('idn.dispositivo', 'CATEGORIA', NULL, 'dispositivo',
 'Dispositivos y Hardware', 'Devices & Hardware',
 'Equipos físicos: biométricos, IoT, industriales, POS, cámaras, HSM, etc.',
 NULL, NULL, NULL, NULL, NULL, '{}', NULL, NULL, NULL, NULL,
 '{}', true, false, false, false,
 '🖥️', NULL, NULL, 'tecnico', 0, false,
 'readWrite', 'none', 'ordinario', false, 1825, 'autoafirmado', NULL, NULL, NULL,
 8, true, NULL);

-- SUBCATEGORIA (nivel 3)
('idn.dispositivo.biometrico', 'SUBCATEGORIA', NULL, 'biometrico',
 'Dispositivo Biométrico', 'Biometric Device',
 'Lectores de huella, iris, cara, vena de palma — ISO/IEC 30107, FIDO2',
 NULL, NULL, NULL, NULL, NULL, '{}', NULL, NULL, NULL, NULL,
 '{}', true, false, false, false,
 '👆', NULL, NULL, 'tecnico', 1, false,
 'readWrite', 'none', 'biometrico', true, 365, 'autoafirmado', NULL, NULL, NULL,
 2, true, 'ISO/IEC 19795 · ISO/IEC 30107 · FIDO2');

-- SUB_SUBCATEGORIA (nivel 4 — solo en dispositivo.acceso)
('idn.dispositivo.acceso.rfid', 'SUB_SUBCATEGORIA', NULL, 'rfid',
 'Lector RFID / NFC', 'RFID / NFC Reader',
 'Lectores de tarjetas RFID, NFC, ISO14443A/B, DESFire, MIFARE',
 NULL, NULL, NULL, NULL, NULL, '{}', NULL, NULL, NULL, NULL,
 '{}', true, false, false, false,
 '💳', NULL, NULL, 'tecnico', 0, false,
 'readWrite', 'none', 'ordinario', false, 1825, 'autoafirmado', NULL, NULL, NULL,
 1, true, 'ISO 14443 · ISO 15693 · OSDP v2');

-- TIPO (hoja ENUM) — enum_options reemplaza allowed_values del JSONB
('idn.dispositivo.biometrico.tipo_biometrico', 'TIPO', 8100, 'tipo_biometrico',
 'Tipo Biométrico', 'Biometric Type',
 'Modalidad biométrica del dispositivo — define qué subcampos aplican',
 'ENUM',
 'huella_dactilar',
 ARRAY['huella_dactilar','iris','cara','vena_palma','vena_dedo','multimodal'],
 NULL,
 'huella_dactilar / iris / cara / vena_palma / multimodal',
 '{}'::jsonb,
 5820, NULL, NULL, NULL,
 '{pos,actor}', false, false, false, false,
 '👆', 'Tipo Biom.', 'Seleccione la modalidad biométrica del dispositivo',
 'tecnico', 1, true,
 'immutable', 'none', 'biometrico', true, 365, 'autoafirmado', NULL, NULL, NULL,
 1, true, 'ISO/IEC 30107 · FIDO2 AAGUID');

-- TIPO (hoja E164) — enum_options=NULL, mask y validation_policy llevan el resto
('idn.contacto.telefono.telefono_movil', 'TIPO', 2001, 'telefono_movil',
 'Teléfono Móvil', 'Mobile Phone',
 'Número de teléfono móvil en formato E.164 con código de país',
 'E164',
 NULL,
 NULL,
 '+## (###) ###-####',
 '+591 71234567',
 '{"regex":"^\\+[1-9]\\d{7,14}$","normalize":"E164_ITU"}'::jsonb,
 5814, 5829, 5830, 5831,
 '{tenant,bdomain,bsubdomain,pos,actor}', true, true, false, true,
 '📱', 'Tel. Móvil', 'Incluya código de país. Ej: +591 71234567',
 'contacto', 1, false,
 'readWrite', 'none', 'ordinario', false, 1825, 'autoafirmado', 'sms_otp',
 'phoneNumbers.value', 'phone_number',
 1, true, 'ITU-T E.164 · SCIM 2.0 RFC 7643 · OIDC Core 1.0');
```

---

### 11.6 Consultas que habilita el árbol ltree

```sql
-- 1. Todos los tipos de dispositivo (cualquier subcategoría)
SELECT tipo_code, path, nombre_es, icono, hint_crud
FROM bauth.idn_tipo_catalogo
WHERE path <@ 'idn.dispositivo'::ltree AND nivel = 'TIPO'
ORDER BY path;
-- Retorna ~135 tipos en una sola query sin JOINs

-- 2. Solo los SUBCATEGORIAS de dispositivo (para menú de formulario)
SELECT node_key, nombre_es, icono, descripcion
FROM bauth.idn_tipo_catalogo
WHERE path <@ 'idn.dispositivo'::ltree AND nivel = 'SUBCATEGORIA'
ORDER BY sort_order;
-- Retorna: generico, biometrico, acceso, iot_sensor, industrial, medico_disp,
--          atm, pos, camara, medidor, red_seguridad, hsm

-- 3. Árbol completo de contacto (para formulario de contacto humano)
SELECT nlevel(path) AS profundidad, node_key, nombre_es, icono
FROM bauth.idn_tipo_catalogo
WHERE path <@ 'idn.contacto'::ltree
ORDER BY path;
-- Retorna: contacto (1) + telefono/email/red_social (3) + 28 tipos hoja

-- 4. Solo tipos que aplican a HUMAN y son especial_art9 (GDPR sensibles)
SELECT tipo_code, path, nombre_es, gdpr_categoria, retencion_dias
FROM bauth.idn_tipo_catalogo
WHERE nivel = 'TIPO'
  AND aplica_a @> ARRAY['actor']
  AND gdpr_categoria IN ('especial_art9','biometrico')
ORDER BY path;
-- Retorna: genero, tipo_sangre, seguro_medico, datos_biometricos, FHIR...

-- 5. Tipos verificables con SIN Bolivia (para proceso de onboarding)
SELECT tipo_code, path, nombre_es, etiqueta_corta, hint_crud
FROM bauth.idn_tipo_catalogo
WHERE nivel = 'TIPO'
  AND servicio_verificacion = 'sin_bolivia'
ORDER BY path;
-- Retorna: nit_bo, autorizacion_sfv

-- 6. Todos los tipos con IAL2 o superior (proofing remoto/presencial)
SELECT tipo_code, path, nombre_es, ial_minimo, servicio_verificacion
FROM bauth.idn_tipo_catalogo
WHERE nivel = 'TIPO' AND ial_minimo IN ('IAL2','IAL3')
ORDER BY ial_minimo, path;

-- 7. Ancestors de un tipo (breadcrumb en formulario)
SELECT path, nombre_es, icono
FROM bauth.idn_tipo_catalogo
WHERE path @> 'idn.dispositivo.biometrico.tipo_biometrico'::ltree
ORDER BY path;
-- Retorna: idn, idn.dispositivo, idn.dispositivo.biometrico,
--           idn.dispositivo.biometrico.tipo_biometrico

-- 8. Tipos inmutables (readOnly/immutable) por categoría (para UI read-only)
SELECT tipo_code, path, nombre_es, mutabilidad
FROM bauth.idn_tipo_catalogo
WHERE nivel = 'TIPO' AND mutabilidad IN ('readOnly','immutable')
ORDER BY path;
```

---

### 11.7 Problemas detectados en la prueba de escritorio

#### Problema A — `facturacion` vs `financiero`: ¿categoría independiente o fusión?

**Situación actual:** `facturacion` (11001-11006) y `financiero` (7001-7011) son categorías
separadas. Sin embargo, para un formulario ambas aparecen en la pestaña "Financiero".

**Opciones:**
```
Opción 1 (fusión):   idn.financiero.bancario.*  (7001-7011)
                     idn.financiero.facturacion.* (11001-11006)

Opción 2 (separado): idn.financiero.bancario.*  (7001-7011)
                     idn.facturacion.fiscal.*    (11001-11006)
```

**Veredicto:** Fusión → `idn.financiero.facturacion.*` porque:
- Para HUMAN solo aplica `bancario`. Para tenant/bdomain aplica `facturacion`.
- `aplica_a` diferencia quién usa qué — la jerarquía no necesita separación.
- Reduce una CATEGORIA innecesaria.

---

#### Problema B — `suscripcion` es de tenant, no de identidad de actor

**Situación actual:** `suscripcion` (10001-10006) vive con tipos de atributo de actor
aunque solo aplica a `tenant`.

**Opciones:**
```
Opción 1: Mantener en idn — aplica_a='{tenant}' distingue
Opción 2: Mover a cfg_tenant_config (la tabla de configuración del tenant)
```

**Veredicto:** Mover a `cfg_tenant_config`. El plan/límites del tenant NO son atributos
de identidad — son configuración del plan SaaS. `idn_tipo_catalogo` debe ser
**solo identidad**. Los tipos 10001-10006 salen del árbol `idn`.

---

#### Problema C — `9010-9014` estaban dispersos entre `profesional` y `seguridad`

**Situación actual:**
- 9010 `matricula_medica` → documentado en §8.1 bajo HUMAN profesional
- 9013 `consentimiento_tutor` → documentado en §8.2 bajo seguridad
- 9014 `zona_acceso_permitida` → documentado en §8.2 bajo seguridad

**Con ltree:** tienen un hogar canónico:
```
idn.medico.habilitacion_prof.matricula_medica      (9010)
idn.medico.habilitacion_prof.area_medica           (9011)
idn.medico.consentimiento.consentimiento_tutor     (9013)
idn.medico.consentimiento.zona_acceso              (9014)
```

`zona_acceso_permitida` (9014) es discutible: aplica a visitantes, médicos y menores.
No es exclusivo de médico. Solución: moverlo a `idn.seguridad.acceso.zona_acceso`.

---

#### Problema D — profundidad variable en `dispositivo.acceso` (nivel 5)

El único subárbol que llega a 5 niveles es:
```
idn.dispositivo.acceso.rfid.tipo_tarjeta    ← 5 niveles
```

¿Es un problema? No. ltree soporta paths arbitrariamente largos.
La query `path <@ 'idn.dispositivo.acceso'::ltree` retorna RFID + PIN + cerradura + sus hojas.

---

#### Problema E — tipo_code 9998/9999 (`extension`) y su path

Los tipos de extensión no tienen una subcategoría natural. Ruta propuesta:
```
idn.extension.libre.atributo_extension_texto   (9998)
idn.extension.libre.atributo_extension_jsonb   (9999)
```

Cuando un tipo de extensión se estandariza → se crea su nodo canónico en el árbol
y el tipo_code 9998/9999 queda como alias temporal.

---

### 11.8 Árbol corregido post-prueba

```
idn                                BIBLIOTECA
├── personal                       CATEGORIA  (14 tipos)
│   ├── nombre                     SUBCATEGORIA
│   └── biografico                 SUBCATEGORIA
├── contacto                       CATEGORIA  (28 tipos)
│   ├── telefono                   SUBCATEGORIA
│   ├── email                      SUBCATEGORIA
│   └── red_social                 SUBCATEGORIA
├── documento                      CATEGORIA  (48 tipos)
│   ├── identidad                  SUBCATEGORIA
│   └── tributario                 SUBCATEGORIA
├── ubicacion                      CATEGORIA  (5 tipos)
│   └── direccion                  SUBCATEGORIA
├── profesional                    CATEGORIA  (29 tipos)
│   ├── empleo                     SUBCATEGORIA
│   ├── educacion                  SUBCATEGORIA
│   └── visita                     SUBCATEGORIA
├── medico                         CATEGORIA  (4 tipos)
│   ├── habilitacion_prof          SUBCATEGORIA
│   └── consentimiento             SUBCATEGORIA
├── financiero                     CATEGORIA  (17 tipos)
│   ├── bancario                   SUBCATEGORIA   (7001-7011)
│   └── facturacion                SUBCATEGORIA   (11001-11006) ← fusionado
├── seguridad                      CATEGORIA  (1 tipo)
│   └── acceso                     SUBCATEGORIA
│       └── zona_acceso            TIPO   (9014) ← movido
├── dispositivo                    CATEGORIA  (135 tipos)
│   ├── generico                   SUBCATEGORIA
│   ├── biometrico                 SUBCATEGORIA
│   ├── acceso                     SUBCATEGORIA
│   │   ├── rfid                   SUB_SUBCATEGORIA
│   │   ├── pin                    SUB_SUBCATEGORIA
│   │   └── cerradura              SUB_SUBCATEGORIA
│   ├── iot_sensor                 SUBCATEGORIA
│   ├── industrial                 SUBCATEGORIA
│   ├── medico_disp                SUBCATEGORIA
│   ├── atm                        SUBCATEGORIA
│   ├── pos                        SUBCATEGORIA
│   ├── camara                     SUBCATEGORIA
│   ├── medidor                    SUBCATEGORIA
│   ├── red_seguridad              SUBCATEGORIA
│   └── hsm                        SUBCATEGORIA
├── vehiculo                       CATEGORIA  (15 tipos)
│   ├── terrestre                  SUBCATEGORIA
│   └── aereo                      SUBCATEGORIA
├── software                       CATEGORIA  (35 tipos)
│   ├── servicio_daemon            SUBCATEGORIA
│   ├── api_gateway                SUBCATEGORIA
│   ├── message_broker             SUBCATEGORIA
│   ├── bot_automatizado           SUBCATEGORIA
│   ├── identidad_federada         SUBCATEGORIA
│   └── agente_ia                  SUBCATEGORIA
└── extension                      CATEGORIA  (2 tipos)
    └── libre                      SUBCATEGORIA
```

**Nodos finales corregidos:**
```
BIBLIOTECA          =   1
CATEGORIA           =  13  (suscripcion eliminada → cfg_tenant_config)
SUBCATEGORIA        =  34
SUB_SUBCATEGORIA    =   3
TIPO (hojas)        = ~326
────────────────────────────
Total               = ~377 nodos
```

---

### 11.9 Veredicto de la prueba de escritorio

| Criterio | Resultado |
|---|---|
| ¿Una sola tabla puede reemplazar las 20? | ✅ Sí — ltree absorbe toda la jerarquía |
| ¿Se mantiene la FK desde `idn_atributo`? | ✅ Sí — `tipo_code` sigue siendo la FK estable |
| ¿Los queries son más expresivos que con `categoria` TEXT? | ✅ Sí — `<@` es más potente que `WHERE categoria=...` |
| ¿El patrón es familiar para el equipo? | ✅ Sí — mismo patrón que `cfg_policy_library` |
| ¿Se detectaron inconsistencias? | ✅ Sí — 5 problemas resueltos en §11.7 |
| ¿Profundidad máxima manejable? | ✅ 5 niveles — solo en dispositivo.acceso.rfid |
| ¿Nodos sin tipo_code (internos) son problemáticos? | ✅ No — igual que en cfg_policy_library |
| ¿Hay que cambiar `idn_atributo`? | ✅ No — solo el FK de `tipo_code` se mantiene |
| ¿`suscripcion` sale del catálogo? | ✅ Sí — va a `cfg_tenant_config` (no es identidad) |

**Conclusión:** La tabla `idn_tipo_catalogo` con ltree **reemplaza completamente**
a `idn_tipo_atributo` (plana) y a las 20 tablas de documentación §10.
El seed tendrá ~377 nodos — manejable, auditable, extensible.
El cambio de nombre de tabla es el único breaking change: `idn_atributo.tipo_code`
sigue siendo `SMALLINT FK → idn_tipo_catalogo.tipo_code`. Sin migración de datos.

**Siguiente paso (HITL):** Aprobar el renombrado `idn_tipo_atributo` → `idn_tipo_catalogo`
+ agregar columnas `path ltree` + `nivel` + `node_key` al DDL.

---

*Documento de planificación HITL — sin ejecución en VPS.*
*Requiere aprobación antes de crear la tabla idn_tipo_atributo y modificar idn_atributo.*
