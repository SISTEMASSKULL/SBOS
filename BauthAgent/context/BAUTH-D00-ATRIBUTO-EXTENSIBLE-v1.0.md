# D00 — Modelo de Atributo Extensible: Una Sola Tabla
**Documento:** BAUTH-D00-ATRIBUTO-EXTENSIBLE-v1.0
**Versión:** 1.3.0 · **Clasificación:** INTERNO CRÍTICO
**Fecha:** 2026-07-01 · **Autor:** bauth-developer / sbos-coordinador
**Propósito:** Diseñar una tabla única y genérica que reemplace la proliferación de
tablas específicas (`org_contacto`, `org_documento`, `org_direccion`) y soporte
cualquier tipo de atributo de identidad presente o futuro sin cambiar el DDL.
Define cómo cada atributo se visualiza y valida en el frontend. Analiza cobertura D00-D12.
**Normas:** ISO 24760-2:2025 §6 · SCIM 2.0 RFC 7643 §2.4 · NIST SP 800-63-4 ·
UIT-T E.164 (teléfonos) · RFC 5321 (email) · ISO 8601 (fechas) · ISO 3166-1 (países) ·
ISO 639 (idiomas) · IANA Timezone Database (zonas horarias) ·
Ley 843 Bolivia (NIT) · Ley 1970 Bolivia (CI) · NIST SP 800-53 Rev.5 IA-4
**Reemplaza:** `ANALISIS-D00-MODELO-VERTICAL-CONTACTOS.md` §2 (3 tablas específicas)
**Relacionado:** `BAUTH-D00-IDENTIDAD-ORGANIZACIONAL-MASTER.md`
**Cambios v1.1.0:** Campos `display_format` y `validation_policy` → §2.2 + §2.4 nuevos.
Análisis cobertura universal D00-D12 → §10 nuevo.
**Cambios v1.2.0:** Catálogo de formatos internacionalizado (29 países `ID_XX`, 24 países `TAX_XX`).
Librerías frontend HTML/JS + Flutter para máscaras y validaciones dinámicas → §11 nuevo.
**Cambios v1.3.0:** Integración con catálogos globales del schema `bglobal` (verificado en SBOS_db):
`global_country` (196 países), `global_language` (125 idiomas), `geo_timezone` (319 zonas),
`global_currency` (143 monedas). Tres nuevos `display_format`: `COUNTRY_CODE`, `LOCALE_BCP47`,
`TIMEZONE_IANA`. El `ISO_3166_1_A3` propuesto anteriormente se descarta — se usa `COUNTRY_CODE`
con FK implícita a `bglobal.global_country`. Nueva sección §12 — integración con bglobal.

---

## 1. EL PROBLEMA DE DISEÑO — PROLIFERACIÓN DE TABLAS

### 1.1 El antipatrón "Tabla por Tipo"

El diseño con 3 tablas específicas (`org_contacto`, `org_documento`, `org_direccion`)
cae en el antipatrón denominado **Tabla por Tipo**: cada vez que aparece un nuevo
atributo de identidad, se necesita:

```
Nuevo tipo de dato "idioma"
         ↓
  Nueva tabla DDL              ← ALTER TABLE / nueva migración
  Nueva migración SQL          ← aprobar, revisar, aplicar
  Nuevo struct Rust            ← struct Idioma { ... }
  Nuevo CRUD Rust              ← create_idioma, update_idioma, delete_idioma, list_idiomas
  Nuevos handlers JSON-RPC     ← bauth.actor.idioma.add, .remove, .list
  Nuevos tests                 ← pruebas de integración
  Seeds actualizados           ← datos de ejemplo
  Documentación actualizada    ← MANUAL_DB_DDL, REGISTRO-ESTADO
```

Esto se repite para cada tipo nuevo que se quiera agregar:

| Tipo de atributo | Tabla por tipo |
|-----------------|:--------------:|
| `org_contacto` | ✓ ya propuesta |
| `org_documento` | ✓ ya propuesta |
| `org_direccion` | ✓ ya propuesta |
| `org_idioma` | siguiente? |
| `org_educacion` | siguiente? |
| `org_hobbie` | siguiente? |
| `org_aplicacion` | siguiente? |
| `org_certificacion` | siguiente? |
| `org_red_social` | siguiente? |
| `org_referencia_laboral` | siguiente? |

**El sistema se vuelve inmantenible.** Cada nuevo tipo de atributo multiplica el
código, las pruebas y las migraciones.

### 1.2 Estado actual del DDL — lo que ya existe

El DDL de bAuth (`DDL_skSBOS_db.sql`) usa 3 patrones de extensibilidad:

| Patrón | Tablas que lo usan | Limitación |
|--------|-------------------|-----------|
| JSONB en columna | `idn_user_template.template`, `org_empresa.metadata`, `fis_location.properties` | No permite queries granulares por atributo |
| Tablas dinámicas parametrizadas | `ath_config_d1..d12`, `ath_policy_d1..d12` | Solo para configuración, no para datos de identidad |
| Jerarquía autorreferencial | `fis_location`, `idn_role_template`, `menu_item` | Jerarquía fija predefinida, no flexible |

**NO existe** ninguna tabla de atributos genérica en el DDL actual.
**NO existe** `org_actor` (el actor vive en `idn_user_template`).

---

## 2. LA SOLUCIÓN — TABLA JERÁRQUICA GENÉRICA

### 2.1 El patrón correcto: EAV Jerárquico Implícito

La solución es una sola tabla con jerarquía **implícita en columnas** (no en filas):

```
Jerarquía implícita (en columnas, no en parent_id):
  entidad     → entidad_tipo + entidad_id   = "el actor Ana Flores"
  categoría   → category                    = "profesional"
  tipo        → attr_key                    = "idioma"
  subtipo     → attr_subtype                = "inglés"
  valor       → value_text + value_data     = "avanzado" + {nivel: B2, certif: TOEFL}
```

Esta estructura expresa 5 niveles de jerarquía sin necesitar `parent_id` ni CTEs recursivas.
Las queries son directas:

```sql
-- Dame todos los emails de Ana:
SELECT * FROM idn_atributo
WHERE entidad_id = :ana_uuid AND category = 'contacto' AND attr_key = 'email';

-- Dame todos los idiomas de Ana, ordenados:
SELECT * FROM idn_atributo
WHERE entidad_id = :ana_uuid AND category = 'profesional' AND attr_key = 'idioma'
ORDER BY sort_order, attr_subtype;
```

Sin JOINs. Sin CTEs recursivas. Sin complejidad.

### 2.2 La tabla `idn_atributo`

El nombre usa el prefijo `idn_` porque ISO 24760-2:2025 clasifica todos estos datos
como **"identity attributes"** (atributos de identidad), independientemente de si
pertenecen a un bdomain (empresa) o a un actor (persona).

```sql
-- ============================================================================
-- idn_atributo — Tabla genérica de atributos de identidad extensibles
-- ============================================================================
-- Propósito : Almacenar CUALQUIER atributo de identidad de CUALQUIER entidad
--             D00 (tenant, bdomain, bsubdomain, pos, actor) en una sola tabla.
--             Extensible infinitamente sin cambiar el DDL — solo insertar filas.
-- Normas    : ISO 24760-2:2025 §6 · SCIM 2.0 RFC 7643 §2.4 · NIST SP 800-63-4
-- Reemplaza : Las 3 tablas específicas propuestas: org_contacto, org_documento,
--             org_direccion (que habrían requerido una tabla nueva por cada
--             tipo de atributo futuro).
-- Aprobación: REQUERIDA antes de implementar (ADR-016)
-- ============================================================================

CREATE TABLE bauth.idn_atributo (
  -- Identidad del registro
  id            UUID        NOT NULL DEFAULT gen_random_uuid(),

  -- Entidad propietaria del atributo
  entidad_tipo  TEXT        NOT NULL,   -- 'tenant'|'bdomain'|'bsubdomain'|'pos'|'actor'
  entidad_id    UUID        NOT NULL,   -- FK lógica (sin FK dura: múltiples tablas destino)

  -- Vínculo con el catálogo de privilegios (para control BitMask)
  -- NULL = atributo libre (sin control de acceso específico, hereda política del tenant)
  -- NOT NULL = el átomo D00 correspondiente define qué roles pueden ver/editar este dato
  atom_code     INT,                    -- FK bauth.privilege_atom(atom_code) — OPCIONAL

  -- Clasificación jerárquica implícita del atributo (sin parent_id)
  category      TEXT        NOT NULL,   -- agrupación mayor (ver §2.3)
  attr_key      TEXT        NOT NULL,   -- tipo de dato dentro de la categoría (ver §2.3)
  attr_subtype  TEXT,                   -- variante específica del tipo (work/home/español/MBA...)

  -- Valor del atributo (texto simple O estructura compleja)
  value_text    TEXT,                   -- valor principal legible (email, número, nombre)
  value_data    JSONB,                  -- datos adicionales estructurados (componentes, metadatos)

  -- Presentación y validación (frontend) — ver §2.4 para catálogo completo
  -- display_format: cómo el frontend MUESTRA el valor (código semántico, ej: 'E164', 'CI_BOLIVIA')
  -- validation_policy: JSONB con las reglas que el frontend y backend aplican para validar el valor
  display_format      TEXT,             -- código de formato de visualización (ver §2.4 §A)
  validation_policy   JSONB,            -- política de validación estructurada (ver §2.4 §B)

  -- Control de calidad del valor
  is_primary    BOOLEAN     NOT NULL DEFAULT false,  -- el valor principal de este tipo
  is_verified   BOOLEAN     NOT NULL DEFAULT false,  -- verificado por el sistema o un tercero
  verified_at   TIMESTAMPTZ,
  verified_by   TEXT,                   -- 'manual'|'api_sin'|'api_registro_civil'|'adsib'

  -- Ordenación y auditoría
  sort_order    SMALLINT    NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT pk_idn_atributo PRIMARY KEY (id),
  CONSTRAINT fk_idn_atributo_atom FOREIGN KEY (atom_code)
    REFERENCES bauth.privilege_atom(atom_code),
  CONSTRAINT ck_entidad_tipo CHECK (
    entidad_tipo IN ('tenant','bdomain','bsubdomain','pos','actor')
  ),
  CONSTRAINT ck_valor_presente CHECK (
    value_text IS NOT NULL OR value_data IS NOT NULL
    -- Al menos uno de los dos campos de valor debe estar presente
  )
);

-- Índice principal: búsqueda por entidad + categoría + tipo (el 99% de las queries)
CREATE INDEX ix_idn_atributo_entidad
  ON bauth.idn_atributo (entidad_id, category, attr_key);

-- Índice para control de acceso BitMask: qué entidades tienen atributos con atom_code
CREATE INDEX ix_idn_atributo_atom
  ON bauth.idn_atributo (atom_code, entidad_tipo, entidad_id)
  WHERE atom_code IS NOT NULL;

-- Índice para búsqueda dentro de JSONB estructurado (direcciones, documentos)
CREATE INDEX ix_idn_atributo_data
  ON bauth.idn_atributo USING GIN (value_data)
  WHERE value_data IS NOT NULL;

-- Índice para búsqueda por valor de texto (ej: buscar quién tiene ese email)
CREATE INDEX ix_idn_atributo_valor
  ON bauth.idn_atributo (attr_key, value_text)
  WHERE value_text IS NOT NULL;
```

### 2.3 Catálogo de categorías y tipos (convención, sin tabla adicional)

La jerarquía `category → attr_key → attr_subtype` es un convenio explícito.
No requiere una tabla de catálogo separada — el control es por convención documentada:

**Categoría `contacto` — datos de comunicación**

| attr_key | attr_subtype válidos | atom_code | Clasificación |
|----------|---------------------|:---------:|:-------------:|
| `email` | work, home, billing, legal, technical, notifications, alternate | 5813 | INTERNAL |
| `telefono` | mobile, work, home, work_mobile, whatsapp, fax, emergency, voip, satellite | 5814 | INTERNAL |
| `red_social` | linkedin, twitter, instagram, github, telegram, facebook | — | PUBLIC |
| `mensajeria` | signal, telegram, skype, teams, zoom | — | INTERNAL |

**Categoría `documento` — documentos de identidad**

| attr_key | attr_subtype válidos | atom_code | Clasificación |
|----------|---------------------|:---------:|:-------------:|
| `id_nacional` | CI, DNI, CC, DUI, CURP, CPF | 5826 | CONFIDENTIAL |
| `id_extranjero` | CI_EXT, NIE, CE | 5826 | CONFIDENTIAL |
| `tributario` | NIT, CUIT, RUT, CNPJ, RFC, RUC | 5812 | CONFIDENTIAL |
| `pasaporte` | nacional, diplomatico | 5826 | CONFIDENTIAL |
| `empresa` | NIT, registered_number, CNPJ, NIT_CO | 5812 | CONFIDENTIAL |

**Categoría `ubicacion` — direcciones y localización**

| attr_key | attr_subtype válidos | atom_code | Clasificación |
|----------|---------------------|:---------:|:-------------:|
| `direccion` | work, home, fiscal, registered, billing, delivery, mailing, virtual | 5816 | INTERNAL |
| `coordenadas` | gps, what3words | — | RESTRICTED |

**Categoría `profesional` — perfil profesional**

| attr_key | attr_subtype válidos | atom_code | Clasificación |
|----------|---------------------|:---------:|:-------------:|
| `idioma` | español, inglés, portugués, aymara, quechua, alemán, etc. | — | PUBLIC |
| `educacion` | bachillerato, tecnico, licenciatura, maestria, doctorado, MBA | — | RESTRICTED |
| `certificacion` | nombre libre (TOEFL, AWS, PMP, OSCE, etc.) | — | PUBLIC |
| `experiencia` | empresa anterior (texto libre) | — | RESTRICTED |
| `profesion` | nombre libre (médico, abogado, ingeniero, contador, etc.) | — | RESTRICTED |
| `especialidad` | nombre libre (oncología, derecho penal, etc.) | — | RESTRICTED |
| `numero_matricula` | médico, abogado, arquitecto (registro profesional) | — | CONFIDENTIAL |

**Categoría `personal` — información personal complementaria**

| attr_key | attr_subtype válidos | atom_code | Clasificación |
|----------|---------------------|:---------:|:-------------:|
| `hobbie` | texto libre (fotografía, senderismo, música, etc.) | — | PUBLIC |
| `habilidad` | texto libre (liderazgo, comunicación, etc.) | — | PUBLIC |
| `disponibilidad` | full_time, part_time, freelance, remoto | — | RESTRICTED |

**Categoría `tecnologia` — competencias tecnológicas**

| attr_key | attr_subtype válidos | atom_code | Clasificación |
|----------|---------------------|:---------:|:-------------:|
| `aplicacion` | nombre libre (SAP, Excel, AutoCAD, etc.) | — | PUBLIC |
| `lenguaje_prog` | nombre libre (Rust, Python, Go, Java, etc.) | — | PUBLIC |
| `plataforma` | nombre libre (AWS, GCP, Azure, etc.) | — | PUBLIC |

### 2.4 Catálogo de Formatos y Políticas de Validación

Los campos `display_format` y `validation_policy` desacoplan la lógica de presentación
y validación del valor de identidad del esquema de la tabla. El backend los almacena;
el frontend los interpreta. Ambos campos son opcionales: si son NULL, el frontend
usa el comportamiento por defecto del tipo.

---

#### §A — `display_format` — Cómo se MUESTRA el valor en el frontend

`display_format TEXT` es un **código semántico** (no una plantilla de cadena) que el
frontend mapea a su lógica de renderización, máscara de entrada, localización, y formato
de copia. El backend no evalúa este campo — lo almacena y lo envía al cliente.

**Principio de nomenclatura — dos niveles:**

```
CÓDIGO UNIVERSAL     → estándar internacional, aplica a todos los países
                       Ejemplos: E164, EMAIL, PASSPORT_ICAO, DATE_ISO, MONEY

CÓDIGO POR PAÍS      → documentos que cada país define con su propia estructura
  ID_XX  → documento de identidad nacional del país XX (ISO 3166-1 alpha-2)
  TAX_XX → documento tributario/fiscal del país XX
           Brasil tiene dos tipos: TAX_BR_CPF (persona) y TAX_BR_CNPJ (empresa)
```

---

**Tabla A1 — Formatos universales** (independientes del país)

| Código | Tipo de dato | Descripción | Ejemplo de salida |
|--------|-------------|-------------|-------------------|
| `E164` | Teléfono | UIT-T E.164 con espaciado amigable por código de país | `+591 71 234-5678` |
| `E164_RAW` | Teléfono | E.164 compacto sin espacios, para copiar/APIs | `+59171234567` |
| `EMAIL` | Email | RFC 5321, lowercase, renderizar como `mailto:` | `ana@empresa.com` |
| `URL` | Web / red social | Dominio visible + renderizar como link | `linkedin.com/in/ana` |
| `DATE_ISO` | Fecha técnica | ISO 8601 `YYYY-MM-DD` — APIs, integración, exportación | `2025-12-31` |
| `DATE_DMY` | Fecha regional | `DD/MM/YYYY` — LATAM, Europa, África, Asia-Pacífico | `31/12/2025` |
| `DATE_MDY` | Fecha regional | `MM/DD/YYYY` — USA, Canadá, algunos países Asia | `12/31/2025` |
| `PASSPORT_ICAO` | Pasaporte | ICAO Doc 9303 Part 3 — universal para todos los países | `BA 098765` |
| `COORDENADAS_DD` | GPS | Decimal Degrees — para renderizar en mapas | `-16.5025, -68.1433` |
| `COORDENADAS_DMS` | GPS | Grados Minutos Segundos — para mostrar a usuarios | `16°30'09"S 68°08'36"O` |
| `MONEY` | Moneda / importe | ISO 4217: símbolo del locale del tenant + monto | `Bs. 1.500,00` / `$ 1,500.00` |
| `NIVEL_CEFR` | Nivel de idioma | Marco Europeo de Referencia — `A1` a `C2` | `B2 — Avanzado` |
| `COUNTRY_CODE` | País / nacionalidad | ISO 3166-1 alpha-2 (2 letras). Frontend resuelve nombre completo desde `bglobal.global_country` | `BO` → `Bolivia` |
| `LOCALE_BCP47` | Idioma / locale | IETF BCP 47. Frontend resuelve nombre e icono desde `bglobal.global_language` | `es-BO` → `Español (Bolivia)` |
| `TIMEZONE_IANA` | Zona horaria | Identificador IANA. Frontend resuelve offset y nombre desde `bglobal.geo_timezone` | `America/La_Paz` → `BOT (UTC-4)` |
| `TEXTO_LIBRE` | Texto sin estructura | Sin transformación, mostrar tal cual | `fotografía de naturaleza` |
| `NOMBRE_PROPIO` | Nombre, profesión | Title Case — primera letra de cada palabra en mayúscula | `Ingeniería de Sistemas` |
| `ACRONIMO` | Sigla, código | UPPERCASE | `AWS` |

---

**Tabla A2 — Documentos de identidad nacional — `ID_XX`**

El código `XX` es el ISO 3166-1 alpha-2 del país emisor del documento.
El frontend carga la máscara y formato según el código — sin condicionantes en el backend.

| Código | País | Nombre oficial del documento | Ejemplo de salida | Estructura |
|--------|------|------------------------------|-------------------|-----------|
| `ID_BO` | Bolivia | Cédula de Identidad (CI) | `7123456 LP` | número 5-8 dígitos + espacio + ext. departamento (2 letras) |
| `ID_PE` | Perú | DNI (Documento Nacional de Identidad) | `12345678` | 8 dígitos |
| `ID_AR` | Argentina | DNI (Documento Nacional de Identidad) | `12.345.678` | 7-8 dígitos con puntos |
| `ID_CL` | Chile | RUN / RUT (persona natural) | `12.345.678-9` | dígitos con puntos + guión + DV alfanumérico |
| `ID_BR` | Brasil | CPF (Cadastro de Pessoas Físicas) | `123.456.789-09` | 11 dígitos, puntos y guión |
| `ID_CO` | Colombia | Cédula de Ciudadanía | `1.234.567.890` | 6-10 dígitos, puntos opcionales |
| `ID_MX` | México | CURP (Clave Única de Registro de Población) | `HEGG560427MVZRRL04` | 18 chars alfanuméricos |
| `ID_EC` | Ecuador | Cédula de Identidad | `1234567890` | 10 dígitos exactos |
| `ID_VE` | Venezuela | Cédula de Identidad | `V-12345678` | prefijo `V` (venezolano) o `E` (extranjero) + dígitos |
| `ID_PY` | Paraguay | Cédula de Identidad | `1234567` | 6-8 dígitos |
| `ID_UY` | Uruguay | Cédula de Identidad | `1.234.567-8` | 7-8 dígitos + DV, con puntos y guión |
| `ID_PA` | Panamá | Cédula Nacional de Identidad | `8-123-4567` | zona + tomo + folio (con guiones) |
| `ID_CR` | Costa Rica | Cédula de Identidad | `1-1234-5678` | provincia + tomo + asiento |
| `ID_GT` | Guatemala | DPI (Documento Personal de Identificación) | `1234567890123` | 13 dígitos |
| `ID_SV` | El Salvador | DUI (Documento Único de Identidad) | `12345678-9` | 8 dígitos + guión + DV |
| `ID_HN` | Honduras | DNI / TID (Tarjeta de Identidad) | `0801-1990-12345` | municipio + año + consecutivo |
| `ID_NI` | Nicaragua | Cédula de Identidad | `001-230170-0001P` | región + fecha + consecutivo + letra |
| `ID_DO` | Rep. Dominicana | Cédula de Identidad y Electoral | `001-1234567-1` | 11 dígitos con guiones |
| `ID_CU` | Cuba | Carné de Identidad | `78032012345` | 11 dígitos: AAMMDD + secuencia + DV |
| `ID_ES` | España | DNI / NIE | `12345678Z` / `X1234567Z` | 8 dígitos + letra control |
| `ID_DE` | Alemania | Personalausweis / Reisepass | `T220001293` | alfanumérico 9-10 chars |
| `ID_FR` | Francia | CNI (Carte Nationale d'Identité) | `1234567890123` | 12-13 dígitos |
| `ID_IT` | Italia | Carta d'Identità Elettronica | `AA12345BB` | 2 letras + 5 dígitos + 2 letras |
| `ID_PT` | Portugal | Cartão de Cidadão | `12345678` | 8 dígitos (número de BI) |
| `ID_GB` | Reino Unido | National Insurance Number | `AB 12 34 56 C` | 2 letras + 6 dígitos + 1 letra |
| `ID_US` | USA | SSN (Social Security Number) ⚠️ | `XXX-XX-XXXX` | ⚠️ sensible — enmascarar siempre |
| `ID_CA` | Canadá | SIN (Social Insurance Number) ⚠️ | `XXX-XXX-XXX` | ⚠️ sensible — enmascarar siempre |
| `ID_JP` | Japón | My Number (個人番号) | `XXXX-XXXX-XXXX` | 12 dígitos (mostrar enmascarado) |
| `ID_CN` | China | 居民身份证 (Resident Identity Card) | `XXXXXXXXXXXXXXXXXX` | 18 chars: región+fecha+secuencia+DV |
| `ID_IN` | India | Aadhaar | `XXXX-XXXX-XXXX` | 12 dígitos — siempre enmascarar |
| `ID_ZA` | Sudáfrica | ID Number | `YYMMDDSSSSCCZ` | 13 dígitos: fecha + género + ciudadanía + DV |

---

**Tabla A3 — Documentos tributarios / fiscales — `TAX_XX`**

| Código | País | Nombre oficial | Ejemplo de salida | Estructura |
|--------|------|----------------|-------------------|-----------|
| `TAX_BO` | Bolivia | NIT (Número de Identificación Tributaria) | `100023456` | 8-12 dígitos, sin separadores |
| `TAX_AR` | Argentina | CUIT / CUIL | `20-12345678-9` | tipo + 8 dígitos + DV (guiones) |
| `TAX_CL` | Chile | RUT empresa | `76.123.456-7` | dígitos con puntos + guión + DV |
| `TAX_BR_CPF` | Brasil persona | CPF (Cadastro de Pessoas Físicas) | `123.456.789-09` | igual a `ID_BR` |
| `TAX_BR_CNPJ` | Brasil empresa | CNPJ (Cadastro Nacional da Pessoa Jurídica) | `12.345.678/0001-90` | 14 dígitos con separadores |
| `TAX_MX` | México | RFC (Registro Federal de Contribuyentes) | `ABC121201AB7` | 4 letras + 6 dígitos fecha + 3 alfanumérico |
| `TAX_CO` | Colombia | NIT (Número de Identificación Tributaria) | `123.456.789-0` | dígitos + DV |
| `TAX_PE` | Perú | RUC (Registro Único de Contribuyentes) | `20123456789` | 11 dígitos, empieza con 10 o 20 |
| `TAX_EC` | Ecuador | RUC (Registro Único de Contribuyentes) | `1234567890001` | 13 dígitos |
| `TAX_PY` | Paraguay | RUC (Registro Único de Contribuyentes) | `12345678-9` | dígitos + guión + DV |
| `TAX_UY` | Uruguay | RUT (Registro Único Tributario) | `211234560001` | 12 dígitos |
| `TAX_VE` | Venezuela | RIF (Registro de Información Fiscal) | `J-12345678-9` | prefijo tipo (`J`/`V`/`G`/`E`) + dígitos + DV |
| `TAX_DO` | Rep. Dominicana | RNC (Registro Nacional del Contribuyente) | `1-23-45678-9` | 9 dígitos con guiones |
| `TAX_GT` | Guatemala | NIT (Número de Identificación Tributaria) | `1234567-8` | dígitos + DV |
| `TAX_CR` | Costa Rica | Cédula Jurídica | `3-101-123456` | 10 dígitos con guiones |
| `TAX_PA` | Panamá | RUC (Registro Único de Contribuyentes) | `8-123-4567 DV-34` | cédula + DV adicional |
| `TAX_SV` | El Salvador | NIT (Número de Identificación Tributaria) | `0614-120580-101-3` | fecha + código + DV |
| `TAX_ES` | España | CIF / NIF empresa | `B12345678` | 1 letra tipo + 7 dígitos + DV |
| `TAX_DE` | Alemania | Steuernummer | `12/345/67890` | variable por Land (estado federado) |
| `TAX_FR` | Francia | SIREN / SIRET | `123 456 789` / `123 456 789 00012` | 9 dígitos SIREN, 14 SIRET |
| `TAX_IT` | Italia | Codice Fiscale / Partita IVA | `RSSMRA85T10A562S` | 16 chars alfanumérico (persona) |
| `TAX_GB` | Reino Unido | UTR / VAT Number | `GB 123 4567 89` | prefijo GB + 9 dígitos |
| `TAX_US` | USA | EIN (Employer Identification Number) | `12-3456789` | XX-XXXXXXX |
| `TAX_CA` | Canadá | BN (Business Number) | `123456789 RT0001` | 9 dígitos + programa + ref |

---

**Tabla A4 — Máscaras de entrada por formulario UX**

La máscara de entrada controla cómo el usuario ingresa el valor — autoformateo en tiempo real.
El backend recibe el valor ya en formato canónico (`normalize` en `validation_policy`).

| Código | Máscara de formulario | Resultado canonico almacenado |
|--------|-----------------------|-------------------------------|
| `E164` | Selector de código de país `+XX` + campo numérico libre | `+59171234567` (sin espacios) |
| `EMAIL` | Sin máscara — texto libre | `usuario@empresa.com` |
| `DATE_DMY` | `##/##/####` | `2025-12-31` (ISO 8601 interno) |
| `DATE_MDY` | `##/##/####` | `2025-12-31` (ISO 8601 interno) |
| `DATE_ISO` | `####-##-##` | `2025-12-31` |
| `ID_BO` | `####### AA` | `7123456 LP` |
| `ID_PE` | `########` | `12345678` |
| `ID_AR` | `##.###.###` | `12345678` (sin puntos, canónico) |
| `ID_CL` | `##.###.###-X` | `12345678-9` |
| `ID_BR` | `###.###.###-##` | `12345678909` (sin separadores) |
| `ID_CO` | `#.###.###.###` | `1234567890` |
| `ID_MX` | `AAAA######HXXXXX##` | `HEGG560427MVZRRL04` |
| `ID_EC` | `##########` | `1234567890` |
| `ID_VE` | `A-########` | `V-12345678` |
| `ID_SV` | `########-#` | `12345678-9` |
| `ID_DO` | `###-#######-#` | `0011234567-1` |
| `ID_ES` | `########A` | `12345678Z` |
| `ID_US` | `###-##-####` | ⚠️ nunca mostrar en claro — enmascarar `***-**-XXXX` |
| `ID_CA` | `###-###-###` | ⚠️ enmascarar siempre |
| `PASSPORT_ICAO` | alfanumérico libre 6-9 chars | `BA098765` (uppercase, sin espacios) |
| `TAX_BO` | `############` sin separadores | `100023456` |
| `TAX_AR` | `##-########-#` | `20-12345678-9` |
| `TAX_CL` | `##.###.###-X` | `76123456-7` |
| `TAX_BR_CNPJ` | `##.###.###/####-##` | `12345678000190` |
| `TAX_BR_CPF` | `###.###.###-##` | `12345678909` |
| `TAX_MX` | `AAAA######XXX` | `ABC121201AB7` |
| `TAX_CO` | `###.###.###-#` | `123456789-0` |
| `TAX_PE` | `###########` | `20123456789` |
| `TAX_VE` | `A-########-#` | `J-12345678-9` |
| `TAX_ES` | `A########` | `B12345678` |
| `MONEY` | `#.###,##` (locale del tenant) | `1500.00` (canónico numérico) |
| `COORDENADAS_DD` | `-##.####, -##.####` | `-16.5025,-68.1433` |
| `COUNTRY_CODE` | Selector dropdown (lista de `bglobal.global_country`) | `BO` (iso_alpha2, 2 letras mayúsculas) |
| `LOCALE_BCP47` | Selector dropdown (lista de `bglobal.global_language`) | `es-BO` (BCP 47, ej. `es`, `es-BO`, `pt-BR`) |
| `TIMEZONE_IANA` | Selector dropdown con búsqueda (lista de `bglobal.geo_timezone`) | `America/La_Paz` (identificador IANA completo) |

---

**Cómo lo usa el frontend:**

```typescript
// AtributoRenderer — mapea display_format a función de presentación
function renderAtributo(row: IdnAtributo): string {
  switch (row.display_format) {
    // Universales
    case 'E164':          return formatE164Display(row.value_text);  // '+591 71 234-5678'
    case 'EMAIL':         return row.value_text?.toLowerCase() ?? '';
    case 'DATE_DMY':      return toLocaleDate(row.value_text, 'DD/MM/YYYY');
    case 'DATE_MDY':      return toLocaleDate(row.value_text, 'MM/DD/YYYY');
    case 'DATE_ISO':      return row.value_text ?? '';
    case 'MONEY':         return formatMoney(row.value_text, tenant.currency_locale);
    case 'NIVEL_CEFR':    return expandCEFR(row.value_text);  // 'B2 — Avanzado'
    case 'PASSPORT_ICAO': return row.value_text?.toUpperCase() ?? '';
    case 'NOMBRE_PROPIO': return toTitleCase(row.value_text ?? '');
    case 'ACRONIMO':      return (row.value_text ?? '').toUpperCase();
    case 'URL':           return renderLink(row.value_text);
    // Catálogos globales — frontend resuelve el nombre desde bglobal.*
    case 'COUNTRY_CODE':  return globalCountry.getName(row.value_text, userLocale);
    // 'BO' → 'Bolivia' (de bglobal.global_country.name_common o name_native[locale])
    case 'LOCALE_BCP47':  return globalLanguage.getName(row.value_text, userLocale);
    // 'es-BO' → 'Español (Bolivia)' (de bglobal.global_language.name[locale])
    case 'TIMEZONE_IANA': return globalTimezone.getLabel(row.value_text, userLocale);
    // 'America/La_Paz' → 'BOT (UTC-4)' (de bglobal.geo_timezone.name[locale] + utc_offset)
    // Identidades nacionales — el formato ya viene canónico del backend
    // El frontend solo aplica la máscara visual correspondiente al país
    default:
      if (row.display_format?.startsWith('ID_') || row.display_format?.startsWith('TAX_'))
        return applyNationalMask(row.display_format, row.value_text ?? '');
      return row.value_text ?? '';
  }
}

// atributoMask — máscara de entrada por código
function getInputMask(displayFormat: string): string | null {
  const masks: Record<string, string> = {
    'DATE_DMY':      '##/##/####',
    'DATE_MDY':      '##/##/####',
    'DATE_ISO':      '####-##-##',
    'ID_BO':         '####### AA',
    'ID_PE':         '########',
    'ID_AR':         '##.###.###',
    'ID_CL':         '##.###.###-X',
    'ID_BR':         '###.###.###-##',
    'ID_CO':         '#.###.###.###',
    'ID_EC':         '##########',
    'ID_SV':         '########-#',
    'TAX_AR':        '##-########-#',
    'TAX_BR_CNPJ':   '##.###.###/####-##',
    'TAX_BR_CPF':    '###.###.###-##',
    'TAX_CO':        '###.###.###-#',
    'TAX_VE':        'A-########-#',
    // Para E164 se usa selector de código de país, no máscara fija
  };
  return masks[displayFormat] ?? null;
}
```

---

#### §B — `validation_policy` — Cómo se VALIDA el valor

`validation_policy JSONB` define las **reglas de validación** que tanto el frontend
(validación inmediata en formulario) como el backend (validación de integridad antes
de persistir) aplican al valor. El JSONB permite expresar cualquier combinación de
reglas sin ampliar el DDL.

**Estructura canónica del JSONB:**

```json
{
  "required": false,
  "regex": "^\\+[1-9]\\d{1,14}$",
  "min_length": 8,
  "max_length": 15,
  "allowed_values": null,
  "normalize": "none",
  "unique_per_entity": false,
  "standard_ref": "UIT-T E.164"
}
```

| Campo | Tipo JSON | Descripción |
|-------|:---------:|-------------|
| `required` | boolean | Si `true`, el atributo no puede ser NULL ni cadena vacía |
| `regex` | string\|null | Expresión regular que el valor DEBE cumplir (escape JSON doble) |
| `min_length` | int\|null | Longitud mínima en caracteres del `value_text` |
| `max_length` | int\|null | Longitud máxima en caracteres del `value_text` |
| `allowed_values` | array\|null | Enum de valores permitidos (para attr_subtype controlados) |
| `normalize` | string | Transformación antes de persistir: `"none"`, `"lowercase"`, `"uppercase"`, `"trim"`, `"strip_spaces"` |
| `unique_per_entity` | boolean | Si `true`, no puede haber dos filas con mismo `attr_key`+`value_text` para la misma `entidad_id` |
| `standard_ref` | string\|null | Referencia normativa: `"UIT-T E.164"`, `"RFC 5321"`, `"ISO 8601"`, `"Ley 843 BO"` |

**Políticas predefinidas por tipo — referencia rápida:**

```json
// ── UNIVERSALES ───────────────────────────────────────────────────────────────

// telefono — E.164 universal (todos los países tienen su prefijo +XX)
{
  "required": false,
  "regex": "^\\+[1-9]\\d{6,14}$",
  "min_length": 8,
  "max_length": 16,
  "normalize": "strip_spaces",
  "unique_per_entity": false,
  "standard_ref": "UIT-T E.164"
}

// email — RFC 5321 (universal)
{
  "required": false,
  "regex": "^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$",
  "max_length": 254,
  "normalize": "lowercase",
  "unique_per_entity": true,
  "standard_ref": "RFC 5321"
}

// pasaporte ICAO (universal — cualquier país emisor)
// El valor_text es el número de pasaporte en formato canónico del país emisor
{
  "required": false,
  "regex": "^[A-Z0-9]{6,10}$",
  "min_length": 6,
  "max_length": 10,
  "normalize": "uppercase",
  "unique_per_entity": true,
  "standard_ref": "ICAO Doc 9303 Part 3"
}

// fecha canónica interna (almacenar siempre ISO 8601, mostrar en display_format)
{
  "required": false,
  "regex": "^\\d{4}-\\d{2}-\\d{2}$",
  "normalize": "none",
  "standard_ref": "ISO 8601"
}

// nivel de idioma CEFR
{
  "required": false,
  "allowed_values": ["A1","A2","B1","B2","C1","C2","nativo","básico","intermedio","avanzado"],
  "normalize": "lowercase",
  "unique_per_entity": false,
  "standard_ref": "CEFR — Marco Europeo Común de Referencia para las Lenguas"
}

// texto libre (hobbie, habilidad, experiencia, profesion, etc.)
{
  "required": false,
  "min_length": 2,
  "max_length": 500,
  "normalize": "trim",
  "unique_per_entity": false
}

// ── DOCUMENTOS DE IDENTIDAD NACIONAL (ID_XX) ─────────────────────────────────

// ID_BO — Cédula de Identidad Bolivia (Ley 1970)
{ "regex": "^\\d{5,8}\\s[A-Z]{2}$", "normalize": "uppercase",   "unique_per_entity": true, "standard_ref": "Ley 1970 Bolivia" }

// ID_PE — DNI Perú (RENIEC)
{ "regex": "^\\d{8}$",              "normalize": "strip_spaces", "unique_per_entity": true, "standard_ref": "Ley 26497 Perú — RENIEC" }

// ID_AR — DNI Argentina (RENAPER)
{ "regex": "^\\d{7,8}$",            "normalize": "strip_spaces", "unique_per_entity": true, "standard_ref": "Ley 17671 Argentina — RENAPER" }

// ID_CL — RUN/RUT persona Chile (Registro Civil)
{ "regex": "^\\d{7,8}-[0-9Kk]$",   "normalize": "uppercase",   "unique_per_entity": true, "standard_ref": "DL 1.263 Chile — Registro Civil" }

// ID_BR — CPF Brasil persona (Receita Federal)
{ "regex": "^\\d{11}$",             "normalize": "strip_spaces", "unique_per_entity": true, "standard_ref": "Lei 9.454/1997 Brasil — Receita Federal CPF" }

// ID_CO — Cédula de Ciudadanía Colombia (Registraduría)
{ "regex": "^\\d{6,10}$",           "normalize": "strip_spaces", "unique_per_entity": true, "standard_ref": "Decreto 1260 Colombia — Registraduría" }

// ID_MX — CURP México (RENAPO)
{ "regex": "^[A-Z]{4}\\d{6}[HM][A-Z]{5}[A-Z0-9]\\d$", "normalize": "uppercase", "unique_per_entity": true, "standard_ref": "DOF 23/oct/1996 México — RENAPO CURP" }

// ID_EC — Cédula de Identidad Ecuador (Registro Civil)
{ "regex": "^\\d{10}$",             "normalize": "strip_spaces", "unique_per_entity": true, "standard_ref": "Ley de Registro Civil Ecuador" }

// ID_VE — Cédula de Identidad Venezuela (SAIME)
{ "regex": "^[VEve]-?\\d{5,8}$",   "normalize": "uppercase",   "unique_per_entity": true, "standard_ref": "SAIME Venezuela" }

// ID_PY — Cédula de Identidad Paraguay (DGREC)
{ "regex": "^\\d{6,8}$",            "normalize": "strip_spaces", "unique_per_entity": true, "standard_ref": "Ley 1266/87 Paraguay — DGREC" }

// ID_UY — Cédula de Identidad Uruguay (DNIC)
{ "regex": "^\\d{7,8}-?\\d$",       "normalize": "strip_spaces", "unique_per_entity": true, "standard_ref": "Ley 18126 Uruguay — DNIC" }

// ID_SV — DUI El Salvador (RNPN)
{ "regex": "^\\d{8}-\\d$",          "normalize": "strip_spaces", "unique_per_entity": true, "standard_ref": "Decreto 2083 El Salvador — RNPN DUI" }

// ID_GT — DPI Guatemala (RENAP)
{ "regex": "^\\d{13}$",             "normalize": "strip_spaces", "unique_per_entity": true, "standard_ref": "Ley RENAP Decreto 90-2005 Guatemala" }

// ID_DO — Cédula República Dominicana (JCE)
{ "regex": "^\\d{3}-\\d{7}-\\d$",  "normalize": "strip_spaces", "unique_per_entity": true, "standard_ref": "Ley Electoral 275-97 RD — JCE" }

// ID_ES — DNI España (FNMT / DGP)
{ "regex": "^\\d{8}[A-HJ-NP-TV-Z]$", "normalize": "uppercase", "unique_per_entity": true, "standard_ref": "RD 896/2003 España — DNI" }

// ── DOCUMENTOS TRIBUTARIOS (TAX_XX) ──────────────────────────────────────────

// TAX_BO — NIT Bolivia (SIN / Ley 843)
{ "regex": "^\\d{8,12}$",              "normalize": "strip_spaces", "unique_per_entity": true, "standard_ref": "Ley 843 Bolivia — SIN NIT" }

// TAX_AR — CUIT/CUIL Argentina (AFIP)
{ "regex": "^\\d{2}-\\d{8}-\\d$",     "normalize": "strip_spaces", "unique_per_entity": true, "standard_ref": "RG AFIP 3832 Argentina — CUIT" }

// TAX_CL — RUT empresa Chile (SII)
{ "regex": "^\\d{1,2}\\.\\d{3}\\.\\d{3}-[0-9Kk]$", "normalize": "uppercase", "unique_per_entity": true, "standard_ref": "DL 824 Chile — SII RUT" }

// TAX_BR_CNPJ — CNPJ Brasil empresa (Receita Federal)
{ "regex": "^\\d{14}$",                "normalize": "strip_spaces", "unique_per_entity": true, "standard_ref": "IN RFB 1183/2011 Brasil — CNPJ" }

// TAX_BR_CPF — CPF Brasil persona (Receita Federal) — igual a ID_BR
{ "regex": "^\\d{11}$",                "normalize": "strip_spaces", "unique_per_entity": true, "standard_ref": "Lei 9.454/1997 Brasil — CPF" }

// TAX_MX — RFC México (SAT)
{ "regex": "^[A-Z]{4}\\d{6}[A-Z0-9]{3}$", "normalize": "uppercase", "unique_per_entity": true, "standard_ref": "CFF Art.27 México — SAT RFC" }

// TAX_CO — NIT Colombia (DIAN)
{ "regex": "^\\d{9}-\\d$",            "normalize": "strip_spaces", "unique_per_entity": true, "standard_ref": "Dec. 624/1989 Colombia — DIAN NIT" }

// TAX_PE — RUC Perú (SUNAT)
{ "regex": "^(10|15|17|20)\\d{9}$",   "normalize": "strip_spaces", "unique_per_entity": true, "standard_ref": "Ley 26935 Perú — SUNAT RUC" }

// TAX_EC — RUC Ecuador (SRI)
{ "regex": "^\\d{13}$",               "normalize": "strip_spaces", "unique_per_entity": true, "standard_ref": "LRTI Art.98 Ecuador — SRI RUC" }

// TAX_PY — RUC Paraguay (SET)
{ "regex": "^\\d{6,8}-\\d$",          "normalize": "strip_spaces", "unique_per_entity": true, "standard_ref": "Ley 125/1991 Paraguay — SET RUC" }

// TAX_VE — RIF Venezuela (SENIAT)
{ "regex": "^[JVGEjvge]-\\d{8}-\\d$", "normalize": "uppercase",   "unique_per_entity": true, "standard_ref": "SENIAT Venezuela — RIF" }

// TAX_GT — NIT Guatemala (SAT)
{ "regex": "^\\d{1,8}-\\d$",          "normalize": "strip_spaces", "unique_per_entity": true, "standard_ref": "Dto. 6-91 Guatemala — SAT NIT" }

// TAX_US — EIN USA (IRS)
{ "regex": "^\\d{2}-\\d{7}$",         "normalize": "strip_spaces", "unique_per_entity": true, "standard_ref": "IRC §6109 USA — IRS EIN" }

// TAX_ES — CIF/NIF empresa España (AEAT)
{ "regex": "^[ABCDEFGHJKLMNPQRSUVW]\\d{7}[A-J0-9]$", "normalize": "uppercase", "unique_per_entity": true, "standard_ref": "RD 1065/2007 España — AEAT CIF" }

// ── CATÁLOGOS GLOBALES (bglobal.*) ───────────────────────────────────────────

// COUNTRY_CODE — ISO 3166-1 alpha-2 (bglobal.global_country) — 196 países
{ "regex": "^[A-Z]{2}$", "min_length": 2, "max_length": 2, "normalize": "uppercase",
  "unique_per_entity": false, "standard_ref": "ISO 3166-1 alpha-2 — bglobal.global_country.iso_alpha2" }

// LOCALE_BCP47 — IETF BCP 47 (bglobal.global_language) — 125 idiomas
{ "regex": "^[a-z]{2,3}(-[A-Z]{2,3})?(-[A-Za-z0-9]{4,8})?$", "min_length": 2, "max_length": 12,
  "normalize": "none", "unique_per_entity": false, "standard_ref": "IETF BCP 47 — bglobal.global_language.locale" }

// TIMEZONE_IANA — IANA tzdata (bglobal.geo_timezone) — 319 zonas
{ "regex": "^[A-Za-z_]+/[A-Za-z_/]+$", "min_length": 5, "max_length": 64,
  "normalize": "none", "unique_per_entity": false, "standard_ref": "IANA Timezone Database — bglobal.geo_timezone.timezone_id" }
```

**Relación entre `display_format` y `validation_policy`:**

Los dos campos son complementarios pero independientes. El `display_format` controla la
**presentación** y la **máscara de entrada**. La `validation_policy` controla la
**corrección del valor**. Ambos se resuelven en el frontend y el backend de forma separada.

```
display_format    = "cómo lo VE el usuario"    (frontend rendering + máscara UX)
validation_policy = "cómo lo ACEPTA el sistema" (frontend inmediato + backend antes de persistir)

Ejemplo — Teléfono celular: cualquier país
  display_format    = 'E164'
  validation_policy = { "regex": "^\\+[1-9]\\d{6,14}$", "standard_ref": "UIT-T E.164" }
  → Bolivia +591 71 234-5678 ✓  |  Colombia +57 300 123 4567 ✓  |  España +34 612 345 678 ✓

Ejemplo — Documento de identidad: depende del país
  Bolivia: display_format='ID_BO', validation_policy={ "regex": "^\\d{5,8}\\s[A-Z]{2}$", ... }
  Perú:    display_format='ID_PE', validation_policy={ "regex": "^\\d{8}$", ... }
  España:  display_format='ID_ES', validation_policy={ "regex": "^\\d{8}[A-HJ-NP-TV-Z]$", ... }
  → Mismo campo `id_nacional` en idn_atributo — solo cambia el display_format y la política
```

**Cómo el backend valida antes de persistir:**

```rust
// En el handler bauth.atributo.crear
fn validar_atributo(row: &NuevoAtributo) -> Result<(), BauthError> {
    let politica: Option<ValidationPolicy> = row.validation_policy
        .as_ref()
        .map(|j| serde_json::from_value(j.clone()))
        .transpose()?;

    if let Some(pol) = politica {
        if pol.required && row.value_text.as_deref().unwrap_or("").is_empty() {
            return Err(BauthError::ValidacionFallida("campo requerido".into()));
        }
        if let Some(regex_str) = &pol.regex {
            let re = Regex::new(regex_str)?;
            let val = row.value_text.as_deref().unwrap_or("");
            if !re.is_match(val) {
                return Err(BauthError::ValidacionFallida(
                    format!("valor no cumple patrón {}", pol.standard_ref.unwrap_or_default())
                ));
            }
        }
        if let Some(maxlen) = pol.max_length {
            if row.value_text.as_deref().unwrap_or("").len() > maxlen {
                return Err(BauthError::ValidacionFallida("valor excede longitud máxima".into()));
            }
        }
    }
    Ok(())
}
```

---

## 3. CÓMO FUNCIONA EN PRÁCTICA

### 3.1 Datos de un actor complejo (Ana Flores, GG Walmart)

```
── CATEGORÍA CONTACTO ──────────────────────────────────────────────────────────
id│ entidad_tipo│ entidad_id  │ atom│ category  │ attr_key  │ attr_subtype│ value_text             │ value_data
──┼─────────────┼─────────────┼─────┼───────────┼───────────┼─────────────┼────────────────────────┼──────────
1 │ actor       │ ana-uuid    │5813 │ contacto  │ email     │ work        │ a.flores@walmart.com.bo│ {verified:true}
2 │ actor       │ ana-uuid    │5813 │ contacto  │ email     │ home        │ anaflores@gmail.com    │ {verified:false}
3 │ actor       │ ana-uuid    │5814 │ contacto  │ telefono  │ work_mobile │ +59179000001           │ {carrier:"Tigo"}
4 │ actor       │ ana-uuid    │5814 │ contacto  │ telefono  │ mobile      │ +59171234567           │ NULL

── CATEGORÍA DOCUMENTO ─────────────────────────────────────────────────────────
5 │ actor       │ ana-uuid    │5826 │ documento │ id_nacional│ CI         │ 7123456 LP             │ {country:"BO",primary:true}
6 │ actor       │ ana-uuid    │5826 │ documento │ pasaporte  │ nacional   │ BA098765               │ {country:"BO",expires:"2030-05-15"}

── CATEGORÍA UBICACION ─────────────────────────────────────────────────────────
7 │ actor       │ ana-uuid    │5816 │ ubicacion │ direccion  │ work       │ Av. Arce 2678 Piso 8   │ {calle:"Av. Arce",numero:"N°2678",piso:"Piso 8",barrio:"Sopocachi",ciudad:"La Paz",pais:"BO"}
8 │ actor       │ ana-uuid    │5816 │ ubicacion │ direccion  │ home       │ C/R. Gutiérrez 500     │ {calle:"C/R. Gutiérrez",numero:"N°500",ciudad:"La Paz",pais:"BO"}

── CATEGORÍA PROFESIONAL ────────────────────────────────────────────────────────
9 │ actor       │ ana-uuid    │NULL │ profesional│ idioma    │ español    │ nativo                 │ {nivel:"C2",certif:false}
10│ actor       │ ana-uuid    │NULL │ profesional│ idioma    │ inglés     │ avanzado               │ {nivel:"B2",certif:"TOEFL",score:89}
11│ actor       │ ana-uuid    │NULL │ profesional│ educacion │ maestria   │ Harvard University     │ {titulo:"MBA International Business",anio:2005}
12│ actor       │ ana-uuid    │NULL │ profesional│ certificacion│ liderazgo│ Harvard Leadership    │ {anio:2018,vigente:true}

── CATEGORÍA PERSONAL ───────────────────────────────────────────────────────────
13│ actor       │ ana-uuid    │NULL │ personal  │ hobbie    │ fotografia  │ fotografía de naturaleza│ {nivel:"amateur"}
14│ actor       │ ana-uuid    │NULL │ personal  │ hobbie    │ senderismo  │ montañismo en Andes    │ NULL

── CATEGORÍA TECNOLOGÍA ─────────────────────────────────────────────────────────
15│ actor       │ ana-uuid    │NULL │ tecnologia│ aplicacion│ ERP        │ SAP                    │ {modulos:["FI","CO","MM"],nivel:"avanzado"}
16│ actor       │ ana-uuid    │NULL │ tecnologia│ aplicacion│ office     │ Microsoft 365          │ {nivel:"avanzado"}
```

**Un actor complejo con 16 atributos de 5 categorías — TODO en una sola tabla.**

### 3.2 Datos de un bdomain (Banco Unión SA)

```
── CONTACTO del BDOMAIN (antes en org_contacto) ─────────────────────────────────
id│ entidad_tipo│ entidad_id    │atom│ category │ attr_key │ attr_subtype│ value_text
──┼─────────────┼───────────────┼────┼──────────┼──────────┼─────────────┼──────────────────────────
1 │ bdomain     │ banco-union-id│5813│ contacto │ email    │ work        │ info@bancounion.bo
2 │ bdomain     │ banco-union-id│5813│ contacto │ email    │ billing     │ facturacion@bancounion.bo
3 │ bdomain     │ banco-union-id│5813│ contacto │ email    │ legal       │ legal@bancounion.bo
4 │ bdomain     │ banco-union-id│5814│ contacto │ telefono │ work        │ +59127270001
5 │ bdomain     │ banco-union-id│5814│ contacto │ telefono │ emergency   │ +59179090000
6 │ bdomain     │ banco-union-id│5812│ documento│ tributario│ NIT        │ 1000234567
7 │ bdomain     │ banco-union-id│5816│ ubicacion│ direccion│ fiscal      │ Av. Camacho 1234, La Paz
```

### 3.3 Agregar nuevos tipos SIN tocar el DDL

```
─── HOY ─────────────────────────────────────────────────────
Agregar emails:     INSERT INTO idn_atributo (category='contacto', attr_key='email', ...)
Agregar teléfonos:  INSERT INTO idn_atributo (category='contacto', attr_key='telefono', ...)

─── MAÑANA — sin DDL, sin migration, sin código nuevo ──────
Agregar idioma:     INSERT INTO idn_atributo (category='profesional', attr_key='idioma', ...)
Agregar educación:  INSERT INTO idn_atributo (category='profesional', attr_key='educacion', ...)
Agregar hobbie:     INSERT INTO idn_atributo (category='personal', attr_key='hobbie', ...)
Agregar aplicación: INSERT INTO idn_atributo (category='tecnologia', attr_key='aplicacion', ...)
Agregar red social: INSERT INTO idn_atributo (category='contacto', attr_key='red_social', ...)
Agregar referencia: INSERT INTO idn_atributo (category='profesional', attr_key='referencia', ...)

─── EN EL FUTURO — lo que no podemos imaginar hoy ──────────
Cualquier cosa:     INSERT INTO idn_atributo (category='nuevo_tipo', attr_key='nuevo_campo', ...)
```

---

## 4. CONTROL DE ACCESO BITMASK — ATRIBUTOS LIBRES VS CONTROLADOS

### 4.1 Atributos controlados (atom_code NOT NULL)

Los atributos con `atom_code` vinculado tienen control de acceso BitMask preciso:

```
email (atom_code=5813):
  → Para ver el email:   rol_bitmask.check(position_of(D00.bdomain_email.ver))
  → Para editar el email: rol_bitmask.check(position_of(D00.bdomain_email.editar))

NIT (atom_code=5812):
  → Solo BIZ_N2+ puede ver
  → Solo BIZ_N1+ puede editar

Documentos (atom_code=5826):
  → El actor puede ver los propios; BIZ_N3+ puede ver los ajenos
  → Solo BIZ_N2+ puede editar/agregar documentos ajenos
```

### 4.2 Atributos libres (atom_code IS NULL)

Los atributos libres (idioma, hobbie, educación, aplicación) NO tienen control por atom_code.
Su acceso se rige por la **política de visibilidad de la categoría**:

| Categoría | Visibilidad por defecto | Quién edita |
|-----------|:-----------------------:|------------|
| `contacto` | El actor ve los propios; manager puede ver | El actor edita los propios; BIZ_N2+ edita los ajenos |
| `profesional` | PUBLIC dentro del tenant | El actor edita los propios; BIZ_N1 puede requerir datos |
| `personal` | Solo el actor | Solo el actor edita (excepto SU/SYS) |
| `tecnologia` | INTERNAL dentro del tenant | El actor edita los propios |

Esta política se implementa en los handlers JSON-RPC verificando la categoría y el
tier del actor solicitante, sin necesidad de un átomo D00 por cada campo.

### 4.3 Auditoría: todo atributo genera audit_event

Toda operación sobre `idn_atributo` — independientemente de si tiene `atom_code` —
genera un `audit_event` con las dimensiones completas (Autenticación Dimensional):

```
CREATE operación sobre categoría 'profesional', attr_key='idioma':
  audit_event.atom_slug  = 'idn_atributo.profesional.idioma.crear'
  audit_event.entidad_id = actor-uuid
  audit_event.actor_id   = quién lo insertó
  audit_event.ctx_id     = ctx_id del contexto activo
  audit_event.result     = Permitido|Denegado
  audit_event.timestamp  = ahora
```

---

## 5. QUERIES TÍPICAS — DEMOSTRACIÓN DE SIMPLICIDAD

```sql
-- Q1: Todos los emails de un actor
SELECT attr_subtype, value_text, is_primary, is_verified
FROM bauth.idn_atributo
WHERE entidad_id = :actor_uuid
  AND category = 'contacto'
  AND attr_key = 'email'
ORDER BY is_primary DESC, sort_order;

-- Q2: Todos los documentos de identidad de un actor
SELECT attr_key, attr_subtype, value_text, value_data->>'country' AS pais,
       (value_data->>'expires')::DATE AS vencimiento, is_verified
FROM bauth.idn_atributo
WHERE entidad_id = :actor_uuid
  AND category = 'documento'
ORDER BY is_primary DESC;

-- Q3: Todos los idiomas que habla un actor
SELECT attr_subtype AS idioma, value_text AS nivel,
       value_data->>'certif' AS certificacion
FROM bauth.idn_atributo
WHERE entidad_id = :actor_uuid
  AND category = 'profesional'
  AND attr_key = 'idioma'
ORDER BY sort_order;

-- Q4: Dirección fiscal de un bdomain (para facturación SIN)
SELECT value_text, value_data
FROM bauth.idn_atributo
WHERE entidad_id = :bdomain_uuid
  AND category = 'ubicacion'
  AND attr_key = 'direccion'
  AND attr_subtype = 'fiscal'
LIMIT 1;

-- Q5: Todos los actores del tenant que conocen SAP
SELECT DISTINCT entidad_id AS actor_uuid
FROM bauth.idn_atributo
WHERE entidad_tipo = 'actor'
  AND category = 'tecnologia'
  AND attr_key = 'aplicacion'
  AND value_text ILIKE 'SAP%';

-- Q6: Atributos controlados por BitMask que un rol puede ver
-- (verificar primero con BitMask, luego leer solo los permitidos)
SELECT id, category, attr_key, attr_subtype, value_text, value_data
FROM bauth.idn_atributo
WHERE entidad_id = :actor_uuid
  AND atom_code = ANY(:atom_codes_permitidos);  -- calculado por BitMask evaluator

-- Q7: Perfil completo de un actor agrupado por categoría
SELECT category,
       jsonb_agg(
         jsonb_build_object(
           'key', attr_key,
           'subtype', attr_subtype,
           'value', value_text,
           'data', value_data,
           'primary', is_primary
         ) ORDER BY sort_order
       ) AS atributos
FROM bauth.idn_atributo
WHERE entidad_id = :actor_uuid
GROUP BY category
ORDER BY category;
```

---

## 6. COMPARACIÓN CON EL DISEÑO ANTERIOR (3 TABLAS ESPECÍFICAS)

| Criterio | 3 tablas específicas | `idn_atributo` (1 tabla) |
|----------|:--------------------:|:------------------------:|
| Tablas necesarias hoy | 3 | 1 |
| DDL para agregar "idioma" mañana | 1 nueva tabla | 0 cambios |
| DDL para agregar "hobbie" | 1 nueva tabla | 0 cambios |
| DDL para agregar "aplicacion" | 1 nueva tabla | 0 cambios |
| DDL para N nuevos tipos en el futuro | N tablas nuevas | 0 cambios |
| Código Rust por tipo de dato | CRUD × 3 structs | CRUD × 1 struct genérico |
| Handlers JSON-RPC | 9-12 handlers | 4 handlers genéricos |
| Queries con JOIN | Necesario para perfil completo | Aggregación en 1 query |
| Indexable para BitMask | Parcialmente | ✅ atom_code indexado |
| Auditabilidad | 1 audit_event por tabla | 1 audit_event unificado |
| Extensibilidad sin DDL | ❌ | ✅ |

---

## 7. CONSIDERACIONES DE PERFORMANCE

### 7.1 ¿Es lento el EAV?

El EAV tiene fama de lento en bases de datos relacionales clásicas. En PostgreSQL 18+
con índices correctos, el impacto es mínimo:

```
Tabla idn_atributo con 10 millones de filas:
  Q1 (emails de un actor) → índice ix_idn_atributo_entidad → < 1ms
  Q4 (dirección fiscal)   → índice ix_idn_atributo_entidad → < 1ms
  Q5 (buscar por app SAP) → índice ix_idn_atributo_valor  → < 5ms
  Q7 (perfil completo)    → índice ix_idn_atributo_entidad + aggregate → < 10ms
```

El índice `(entidad_id, category, attr_key)` cubre el 99% de las queries de producción.

### 7.2 Particionamiento futuro

Si la tabla crece a >100 millones de filas (escenario de millones de actores),
se puede particionar por `entidad_tipo` o por `category` sin cambiar el DDL de
la tabla base ni el código que la usa:

```sql
-- Particionamiento futuro por entidad_tipo (sin cambio de aplicación):
CREATE TABLE bauth.idn_atributo PARTITION BY LIST (entidad_tipo);
CREATE TABLE bauth.idn_atributo_actor    PARTITION OF bauth.idn_atributo FOR VALUES IN ('actor');
CREATE TABLE bauth.idn_atributo_bdomain  PARTITION OF bauth.idn_atributo FOR VALUES IN ('bdomain');
```

---

## 8. IMPACTO EN LOS 20 ÁTOMOS D00

### ¿Cambia algo en los átomos D00 actuales?

**NO. Los 20 átomos siguen siendo exactamente los mismos.**

Lo que cambia es cómo se materializan sus valores:

| Átomo D00 | Antes (3 tablas) | Ahora (idn_atributo) |
|-----------|:----------------:|:--------------------:|
| `bdomain.email` (5813) | Filas en `org_contacto` | Filas en `idn_atributo`, category='contacto', key='email' |
| `bdomain.telefono` (5814) | Filas en `org_contacto` | Filas en `idn_atributo`, category='contacto', key='telefono' |
| `bdomain.direccion` (5816) | Filas en `org_direccion` | Filas en `idn_atributo`, category='ubicacion', key='direccion' |
| `actor.id_doc_type` (5826) | Filas en `org_documento` | Filas en `idn_atributo`, category='documento', key='id_nacional'/etc. |
| `bdomain.nit` (5812) | Columna directa en org_empresa | Fila en `idn_atributo`, category='documento', key='tributario', subtype='NIT' |
| `actor.locale` (5827) | Columna directa en org_actor | Fila en `idn_atributo` O columna directa (1 valor, no se repite) |

**Regla de cardinalidad actualizada:**

```
Dato con cardinalidad 1:1 por entidad y que nunca se repite
  → columna directa en las tablas principales (org_empresa, org_actor futura)
  → ejemplos: bdomain.type, actor.gender, actor.locale, actor.timezone

Dato con cardinalidad 1:N o que puede tener múltiples instancias
  → fila en idn_atributo con category + attr_key + attr_subtype
  → ejemplos: emails, teléfonos, direcciones, documentos, idiomas, etc.
```

---

## 9. ESTADO Y SIGUIENTES PASOS

| Item | Estado | Condición |
|------|:------:|-----------|
| Diseño de `idn_atributo` | ✅ Propuesto en este documento | — |
| Campos `display_format` y `validation_policy` | ✅ Diseñados en §2.2 + §2.4 | — |
| Catálogo de códigos `display_format` | ✅ Definido en §2.4 §A | Por convención, no requiere tabla |
| Políticas predefinidas por tipo | ✅ Definidas en §2.4 §B | Por convención |
| Cobertura D00-D12 | ✅ Analizada en §10 | — |
| DDL formal de `idn_atributo` | ⏳ Pendiente | Aprobación explícita (ADR-016) |
| Handlers JSON-RPC genéricos | ⏳ Pendiente | DDL aprobado |
| Catálogo de categorías/keys | ✅ Definido en §2.3 (por convención) | Permanente |
| Seeds de ejemplo | ⏳ Pendiente | DDL aprobado |
| 3 tablas anteriores (org_contacto, etc.) | 🗑️ **DESCARTADAS** | Reemplazadas por este diseño |
| Librerías frontend (máscaras + validación) | ✅ Documentadas en §11 | IMask.js + Yup (HTML) · flutter_multi_formatter + reactive_forms + intl_phone_field (Flutter) |

---

## 10. COBERTURA DE DOMINIOS D00-D12

### ¿Puede `idn_atributo` servir a todos los dominios, no solo a D00?

**Respuesta: SÍ — con una distinción crítica.**

`idn_atributo` sirve para almacenar **atributos descriptivos de la identidad** de cualquier
entidad, en cualquier dominio. Lo que NO almacena son:
- POLÍTICAS de acceso (esas van a `ath_policy_dN`)
- CONFIGURACIONES de método (esas van a `ath_config_dN`)
- EVENTOS dinámicos (audit_event, ctx_id en Redis, sesiones)

La tabla es **universalmente extensible** — simplemente se agregan nuevas `category`
para cada dominio, sin tocar el DDL.

### 10.1 Mapa de cobertura por dominio

| Dominio | Código | ¿`idn_atributo` aplica? | `category` sugerida | Qué NO va aquí |
|---------|:------:|:-----------------------:|---------------------|----------------|
| **D00** Identidad Organizacional | 0 | ✅ **DISEÑADO** — caso principal | contacto, documento, ubicacion, profesional, personal, tecnologia | Columnas 1:1 de org_empresa/org_sucursal |
| **D1** Acceso Lógico | 1 | ✅ Parcial | `acceso_logico` | privilege_atom, privilege_role — son el DDL de permisos |
| **D2** Acceso Físico | 2 | ✅ Parcial | `acceso_fisico` | fis_location (jerarquía física ya existe) |
| **D3** Financiero | 3 | ✅ Parcial | `financiero` | ath_policy_d3, configuraciones de presupuesto |
| **D4** Temporal | 4 | ✅ Parcial | `temporal` | ath_config_d4 (horarios y restricciones son POLÍTICAS) |
| **D5** Geoespacial | 5 | ✅ Parcial | ya cubierto por `ubicacion` | ath_policy_d5 (zonas permitidas son POLÍTICAS) |
| **D6** Biométrico | 6 | ✅ Referencia | `biometrico` | los templates biométricos son BINARIOS externos |
| **D7** Red / Dispositivo | 7 | ✅ Parcial | `dispositivo` | ath_config_d7 (reglas de red son POLÍTICAS) |
| **D8** Contexto | 8 | ❌ No aplica | — | ctx_id es dinámico, vive en Redis (SBOS-049) |
| **D9** Delegación | 9 | ✅ Parcial | `delegacion` | las relaciones de delegación tienen su tabla propia |
| **D10** Auditoría | 10 | ❌ No aplica | — | audit_event es un log append-only, no un atributo |
| **D11** Compliance | 11 | ✅ Parcial | `compliance` | ath_policy_d11 (declaraciones de cumplimiento son POLÍTICAS) |
| **D12** Blockchain | 12 | ✅ Referencia | `blockchain` | los bloques blockchain son registros externos |

### 10.2 Atributos representativos por dominio

**D1 — Acceso Lógico** (`category='acceso_logico'`)

```
attr_key='metodo_mfa_preferido'   attr_subtype='totp'|'webauthn'|'email_otp'
attr_key='dispositivo_confiable'  attr_subtype='fingerprint_id'   value_text=hash_del_dispositivo
attr_key='pin_backup'             attr_subtype='encrypted'         value_data={hash:..., alg:'argon2id'}
```

**D2 — Acceso Físico** (`category='acceso_fisico'`)

```
attr_key='zona_asignada'          attr_subtype='permanente'|'temporal'  value_text='ZONA-SERVIDORES'
attr_key='carne_acceso'           attr_subtype='rfid'                   value_text='TAG-0000-AB12'
attr_key='vehiculo'               attr_subtype='placa'                  value_text='3456-BCD'
```

**D3 — Financiero** (`category='financiero'`)

```
attr_key='cuenta_bancaria'        attr_subtype='corriente'|'ahorro'     value_data={banco:'BNB',nro:'00-1234',moneda:'BOB'}
attr_key='centro_costo'           attr_subtype='principal'              value_text='CC-LOGISTICA-001'
attr_key='limite_gasto'           attr_subtype='mensual'                value_text='5000'
```

**D4 — Temporal** (`category='temporal'`)

```
attr_key='disponibilidad'         attr_subtype='laboral'    value_text='lunes-viernes'
attr_key='zona_horaria'           attr_subtype='principal'  value_text='America/La_Paz'
attr_key='contrato_vigencia'      attr_subtype='fin'        value_text='2027-12-31'
```

**D5 — Geoespacial** (ya en `category='ubicacion'`)

```
attr_key='coordenadas'            attr_subtype='oficina'    value_data={lat:-16.5025,lon:-68.1433,radio_m:50}
attr_key='zona_geografica'        attr_subtype='operativa'  value_text='Altiplano Norte'
```

**D6 — Biométrico** (`category='biometrico'`)

```
attr_key='template_ref'           attr_subtype='huella_digital'  value_text='ref://bionexus/actor/ana-uuid/huella/1'
attr_key='template_ref'           attr_subtype='facial'          value_text='ref://bionexus/actor/ana-uuid/face/1'
-- NOTA: los templates biométricos son externos (bhnexus). idn_atributo guarda solo la REFERENCIA.
```

**D7 — Red / Dispositivo** (`category='dispositivo'`)

```
attr_key='mac_address'            attr_subtype='laptop'     value_text='AA:BB:CC:DD:EE:FF'
attr_key='ip_confiable'           attr_subtype='vpn'        value_text='10.0.0.45'
attr_key='certificado_cliente'    attr_subtype='mtls'       value_data={fingerprint:'SHA256:...',valid_to:'2027-01-01'}
attr_key='app_instalada'          attr_subtype='corporativa' value_text='SAP Fiori'
```

**D9 — Delegación** (`category='delegacion'`)

```
attr_key='contacto_emergencia'    attr_subtype='persona'    value_data={nombre:'Carlos Flores',tel:'+59171000001',relacion:'hermano'}
attr_key='apoderado_legal'        attr_subtype='nit'        value_text='12345678'
```

**D11 — Compliance** (`category='compliance'`)

```
attr_key='certificacion_iso'      attr_subtype='27001'    value_data={entidad:'Bureau Veritas',vence:'2028-05-15',nro_cert:'BV-27001-2025'}
attr_key='declaracion'            attr_subtype='riesgo_it' value_data={firmado_por:'ana-uuid',fecha:'2025-03-01',hash:'sha256:...'}
attr_key='capacitacion'           attr_subtype='gdpr'     value_text='completada' value_data={curso:'GDPR Essentials',anio:2024}
```

**D12 — Blockchain** (`category='blockchain'`)

```
attr_key='wallet_address'         attr_subtype='ethereum'  value_text='0xABCDEF...'  value_data={red:'mainnet',tipo:'EOA'}
attr_key='did'                    attr_subtype='w3c'       value_text='did:ethr:0xABCDEF...'
-- NOTA: los registros de transacción blockchain son eventos externos, no atributos.
```

### 10.3 Principio de diseño — Atributo vs Política vs Evento

```
┌─────────────────────────────────────────────────────────────────────┐
│  ATRIBUTO (idn_atributo)                                            │
│  → Lo que el actor o la entidad ES, TIENE, o SABE de forma estable │
│  → Cambia raramente (datos personales, documentos, dispositivos)    │
│  → Tiene display_format + validation_policy                        │
├─────────────────────────────────────────────────────────────────────┤
│  POLÍTICA (ath_policy_dN)                                           │
│  → Reglas que el SISTEMA aplica SOBRE el actor                      │
│  → Cambia según configuración de seguridad, no del actor            │
│  → No tiene formato de visualización — es configuración interna     │
├─────────────────────────────────────────────────────────────────────┤
│  EVENTO (audit_event, ctx_id en Redis)                              │
│  → Lo que OCURRE en un momento temporal específico                  │
│  → Append-only (ISO 27001 A.8.15) — nunca se modifica              │
│  → No es un atributo del actor — es un registro de acción          │
└─────────────────────────────────────────────────────────────────────┘
```

### 10.4 Tabla de implementación por dominio

| Dominio | `idn_atributo` cubre | Tablas propias del dominio |
|---------|---------------------|--------------------------|
| D00 | 100% de atributos de identidad organizacional | org_empresa, org_sucursal, org_pos_logico |
| D1 | Referencias de configuración MFA, métodos preferidos | privilege_atom, privilege_role, ath_config_d1 |
| D2 | Zonas asignadas, carnés, vehículos | fis_location, fis_location_closure, ath_policy_d2 |
| D3 | Cuentas bancarias, centros de costo, límites | ath_policy_d3, tablas contables (Tryton) |
| D4 | Disponibilidad laboral, vigencia contrato, timezone | ath_config_d4, ath_policy_d4 |
| D5 | Coordenadas de oficina, zonas geográficas operativas | ath_policy_d5 (polígonos permitidos) |
| D6 | Referencias externas a templates biométricos | sistema biométrico externo (bhnexus) |
| D7 | MACs confiables, IPs VPN, certificados cliente, apps | ath_config_d7, ath_policy_d7 |
| D8 | ❌ No aplica — contexto es dinámico | ctx_id en Redis (SBOS-049) |
| D9 | Contactos de emergencia, apoderados legales | tablas de delegación (futuro) |
| D10 | ❌ No aplica — auditoría es append-only | audit_event |
| D11 | Certificaciones ISO, declaraciones firmadas, capacitaciones | ath_policy_d11 |
| D12 | Wallets blockchain, DIDs W3C | sistema blockchain externo |

**Conclusión:** `idn_atributo` actúa como el **repositorio universal de atributos descriptivos
de identidad** para los 13 dominios del SBOS. Cada dominio aporta nuevas `category` y
nuevos `attr_key` sin modificar el DDL. La tabla escala horizontalmente de forma natural.

---

## 11. LIBRERÍAS FRONTEND — MÁSCARAS Y VALIDACIONES

### 11.1 Contexto de integración

El diseño de `display_format` + `validation_policy` en `idn_atributo` permite que
el frontend sea **completamente agnóstico del tipo de documento y del país**:
el backend entrega los dos campos con cada atributo y el frontend construye
dinámicamente el formatter y el validador correspondientes — sin hardcodear nada.

Stack del SBOS: **HTML5 + JS vanilla** (prototipo) → **Flutter 3.44+** (producción)

---

### 11.2 Prototipo — HTML + JavaScript vanilla

#### IMask.js — Máscaras de entrada

La opción más potente para este caso de uso: permite construir el formatter
dinámicamente a partir de un patrón en runtime, sin hardcodear nada.

```bash
npm install imask
# o CDN
<script src="https://unpkg.com/imask"></script>
```

```javascript
// Se construye el formatter dinámicamente desde display_format de la BD
function buildMask(inputEl, displayFormat, validationPolicy) {
  const maskPatterns = {
    // Identidades nacionales
    'ID_BO':       { mask: '0000000 LL', definitions: { L: /[A-Z]/ } },
    'ID_PE':       { mask: '00000000' },
    'ID_AR':       { mask: '00.000.000' },
    'ID_CL':       { mask: '00.000.000-{[K]}0', definitions: { '0': /[0-9Kk]/ } },
    'ID_BR':       { mask: '000.000.000-00' },
    'ID_CO':       { mask: '#.###.###.###', definitions: { '#': /[1-9]/ } },
    'ID_MX':       { mask: /^[A-Z]{4}\d{6}[HM][A-Z]{5}[A-Z0-9]\d$/ },
    'ID_EC':       { mask: '0000000000' },
    'ID_VE':       { mask: 'a-00000000', definitions: { a: /[VEve]/ } },
    'ID_SV':       { mask: '00000000-0' },
    'ID_DO':       { mask: '000-0000000-0' },
    'ID_ES':       { mask: '00000000A', definitions: { A: /[A-HJ-NP-TV-Z]/ } },
    // Tributarios
    'TAX_BO':      { mask: /^\d{8,12}$/ },
    'TAX_AR':      { mask: '00-00000000-0' },
    'TAX_CL':      { mask: '00.000.000-0' },
    'TAX_BR_CNPJ': { mask: '00.000.000/0000-00' },
    'TAX_BR_CPF':  { mask: '000.000.000-00' },
    'TAX_MX':      { mask: /^[A-Z]{4}\d{6}[A-Z0-9]{3}$/ },
    'TAX_CO':      { mask: '000.000.000-0' },
    'TAX_PE':      { mask: '00000000000' },
    'TAX_VE':      { mask: 'a-00000000-0', definitions: { a: /[JVGEjvge]/ } },
    'TAX_ES':      { mask: 'A0000000X', definitions: { A: /[A-Z]/, X: /[A-J0-9]/ } },
    // Fechas
    'DATE_DMY':    { mask: Date, pattern: 'd/`m/`Y' },
    'DATE_MDY':    { mask: Date, pattern: 'm/`d/`Y' },
    'DATE_ISO':    { mask: Date, pattern: 'Y-`m-`d' },
    // Otros
    'EMAIL':       { mask: /^[^@\s]*@?[^@\s]*\.?[^@\s]*$/ },
    'PASSPORT_ICAO': { mask: /^[A-Z0-9]{1,10}$/ },
  };

  const def = maskPatterns[displayFormat];
  if (!def) return null;  // TEXTO_LIBRE, NOMBRE_PROPIO, etc. — sin máscara
  return IMask(inputEl, def);
}
```

**Por qué IMask sobre las alternativas:**

| Librería | Estado | Limitación para este caso |
|----------|:------:|--------------------------|
| **IMask.js** | ✅ Activo | Ninguna — es la más flexible |
| `Cleave.js` | ⚠️ Poco mantenido | Limitado para patrones irregulares (CURP, RIF) |
| `inputmask` (Robin Herbots) | ✅ Activo | Bundle mayor, API más compleja |
| `vanilla-masker` | ❌ Abandonado | — |

#### Yup — Validaciones declarativas desde el JSONB

Permite construir el schema de validación dinámicamente a partir del
`validation_policy` que llega de la BD — sin importar el país ni el tipo de documento.

```javascript
import * as Yup from 'yup';

function buildValidator(validationPolicy) {
  if (!validationPolicy) return Yup.string();

  let schema = Yup.string();

  if (validationPolicy.required)
    schema = schema.required('Campo requerido');

  if (validationPolicy.min_length)
    schema = schema.min(
      validationPolicy.min_length,
      `Mínimo ${validationPolicy.min_length} caracteres`
    );

  if (validationPolicy.max_length)
    schema = schema.max(
      validationPolicy.max_length,
      `Máximo ${validationPolicy.max_length} caracteres`
    );

  if (validationPolicy.regex)
    schema = schema.matches(
      new RegExp(validationPolicy.regex),
      `Formato inválido — ref: ${validationPolicy.standard_ref ?? ''}`
    );

  if (validationPolicy.allowed_values)
    schema = schema.oneOf(validationPolicy.allowed_values, 'Valor no permitido');

  return schema;
}

// Uso — el validator se construye desde los datos de la BD
const validator = buildValidator(row.validation_policy);
validator.validate(inputValue)
  .then(() => clearError())
  .catch(err => showError(err.message));
```

---

### 11.3 Producción — Flutter 3.44+

#### `flutter_multi_formatter` — Máscaras de entrada

```yaml
# pubspec.yaml
dependencies:
  flutter_multi_formatter: ^2.14.0
```

Permite construir `MaskedInputFormatter` dinámicamente desde `display_format`:

```dart
/// Construye el formatter dinámicamente desde display_format
TextInputFormatter? buildMaskFormatter(String displayFormat) {
  // # = dígito obligatorio, @ = letra obligatoria, * = cualquier char
  final patterns = <String, String>{
    // Identidades nacionales
    'ID_BO':       '#######\ @@',
    'ID_PE':       '########',
    'ID_AR':       '##.###.###',
    'ID_CL':       '##.###.###-#',
    'ID_BR':       '###.###.###-##',
    'ID_CO':       '#.###.###.###',
    'ID_EC':       '##########',
    'ID_SV':       '########-#',
    'ID_DO':       '###-#######-#',
    'ID_GT':       '#############',
    // Tributarios
    'TAX_AR':      '##-########-#',
    'TAX_BR_CNPJ': '##.###.###/####-##',
    'TAX_BR_CPF':  '###.###.###-##',
    'TAX_CO':      '###.###.###-#',
    'TAX_VE':      '@-########-#',
    'TAX_ES':      '@#######@',
    // Fechas
    'DATE_DMY':    '##/##/####',
    'DATE_MDY':    '##/##/####',
    'DATE_ISO':    '####-##-##',
  };

  final pattern = patterns[displayFormat];
  if (pattern == null) return null;
  return MaskedInputFormatter(pattern);
}
```

#### `reactive_forms` — Formularios con validación dinámica

```yaml
dependencies:
  reactive_forms: ^17.0.0
```

```dart
/// Construye controles reactivos desde validation_policy JSONB
FormControl<String> buildControl(Map<String, dynamic>? policy) {
  final validators = <Validator<dynamic>>[];

  if (policy?['required'] == true)
    validators.add(Validators.required);

  if (policy?['regex'] != null)
    validators.add(Validators.pattern(policy!['regex']));

  if (policy?['min_length'] != null)
    validators.add(Validators.minLength(policy!['min_length'] as int));

  if (policy?['max_length'] != null)
    validators.add(Validators.maxLength(policy!['max_length'] as int));

  return FormControl<String>(validators: validators);
}
```

#### `intl_phone_field` — Campos telefónicos E.164

```yaml
dependencies:
  intl_phone_field: ^3.2.0
```

```dart
// Carga automáticamente todos los países con sus códigos de marcación
// Valida E.164 internamente — no se necesita regex manual para teléfonos
IntlPhoneField(
  decoration: const InputDecoration(labelText: 'Teléfono'),
  initialCountryCode: tenantCountryCode,   // ISO 3166-1 alpha-2 del tenant
  onChanged: (phone) => control.value = phone.completeNumber,  // '+59171234567'
)
```

---

### 11.4 Widget universal — integración completa

El patrón central que une todo: un widget que recibe `display_format` +
`validation_policy` de `idn_atributo` y construye el campo correcto sin saber
de antemano qué país es ni qué tipo de documento maneja.

```dart
/// Widget genérico para cualquier fila de idn_atributo
/// Recibe display_format + validation_policy del servidor y se autoconfigurea
class AtributoField extends StatelessWidget {
  final String displayFormat;
  final Map<String, dynamic>? validationPolicy;
  final FormControl<String> control;
  final String? label;

  const AtributoField({
    required this.displayFormat,
    required this.control,
    this.validationPolicy,
    this.label,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // E164 → widget especializado con selector de código de país
    if (displayFormat == 'E164') {
      return IntlPhoneField(
        decoration: InputDecoration(labelText: label ?? 'Teléfono'),
        initialCountryCode: context.read<TenantCubit>().state.countryCode,
        onChanged: (phone) => control.value = phone.completeNumber,
      );
    }

    final formatter = buildMaskFormatter(displayFormat);
    final formControl = buildControl(validationPolicy);

    return ReactiveTextField<String>(
      formControl: formControl,
      decoration: InputDecoration(labelText: label),
      inputFormatters: [
        if (formatter != null) formatter,
        // SSN/SIN USA/CA — nunca mostrar en claro
        if (displayFormat == 'ID_US' || displayFormat == 'ID_CA')
          _ObscuringFormatter(),
        // UPPERCASE para documentos que lo requieren
        if (_requiresUppercase(displayFormat))
          UpperCaseTextFormatter(),
      ],
      keyboardType: _keyboardType(displayFormat),
      validationMessages: {
        ValidationMessage.pattern: (_) =>
          'Formato inválido${validationPolicy?['standard_ref'] != null
            ? ' — ${validationPolicy!['standard_ref']}'
            : ''}',
        ValidationMessage.required:  (_) => 'Campo requerido',
        ValidationMessage.minLength: (_) =>
          'Mínimo ${validationPolicy?['min_length']} caracteres',
        ValidationMessage.maxLength: (_) =>
          'Máximo ${validationPolicy?['max_length']} caracteres',
      },
    );
  }

  TextInputType _keyboardType(String fmt) {
    if (fmt.startsWith('ID_') || fmt.startsWith('TAX_'))
      return TextInputType.visiblePassword;  // evita autocomplete no deseado
    if (fmt == 'EMAIL')    return TextInputType.emailAddress;
    if (fmt.startsWith('DATE_')) return TextInputType.datetime;
    if (fmt == 'MONEY')    return const TextInputType.numberWithOptions(decimal: true);
    return TextInputType.text;
  }

  bool _requiresUppercase(String fmt) =>
    const {'ID_CL','ID_MX','ID_VE','ID_ES','TAX_MX','TAX_VE','TAX_ES',
           'PASSPORT_ICAO','ACRONIMO'}.contains(fmt);
}
```

**Agregar soporte para un nuevo país** es solo añadir una entrada al Map de patrones
en `buildMaskFormatter` y una política en `buildValidator` — sin tocar DDL ni backend.

---

### 11.5 Resumen de dependencias por fase

| Librería | Fase | Propósito | Versión |
|----------|:----:|-----------|:-------:|
| `IMask.js` | HTML/JS | Máscaras de entrada dinámicas | `^7.x` |
| `Yup` | HTML/JS | Validación declarativa desde JSONB | `^1.x` |
| `flutter_multi_formatter` | Flutter | Máscaras de entrada dinámicas | `^2.14` |
| `reactive_forms` | Flutter | Formularios + validación dinámica | `^17.x` |
| `intl_phone_field` | Flutter | Teléfonos E.164 con selector de país | `^3.2` |

---

---

## 12. INTEGRACIÓN CON CATÁLOGOS GLOBALES — Schema `bglobal`

### 12.1 Estado real en SBOS_db (verificado 2026-07-01)

El schema `bglobal` existe en `SBOS_db` con 4 tablas de catálogo global completamente
pobladas. Son la **fuente de verdad** para países, idiomas, zonas horarias y monedas.
Ningún agente debe hardcodear estos valores — siempre referenciar estas tablas.

| Tabla | Registros | Estándares | Propósito |
|-------|:---------:|-----------|---------|
| `bglobal.global_country` | **196** | ISO 3166-1 alpha-2/alpha-3/numeric · ITU-T E.164 · UN M.49 · IANA TLD · ICAO | País, código de llamada, moneda, idiomas, zonas horarias |
| `bglobal.global_language` | **125** | ISO 639-1/639-2T/639-2B/639-3 · IETF BCP 47 · IANA Language Subtag Registry | Idioma, locale, dirección (LTR/RTL), familia lingüística |
| `bglobal.geo_timezone` | **319** | IANA Timezone Database (tzdata) | Zona horaria IANA, offset UTC, DST, ciudad principal |
| `bglobal.global_currency` | **143** | ISO 4217 alpha-3/numeric | Moneda, símbolo, decimales, criptomonedas incluidas |

### 12.2 Cómo `idn_atributo` usa `bglobal`

`idn_atributo` almacena el **código canónico** como `value_text`. El frontend resuelve
el nombre completo consultando `bglobal.*` en su idioma activo. El backend valida
que el código existe en `bglobal` antes de persistir.

```
idn_atributo.value_text = 'BO'             (COUNTRY_CODE)
idn_atributo.value_text = 'es-BO'          (LOCALE_BCP47)
idn_atributo.value_text = 'America/La_Paz' (TIMEZONE_IANA)
idn_atributo.value_text = 'BOB'            (MONEY — ya cubierto por global_currency)
```

**Relaciones por `display_format`:**

| `display_format` | Tabla `bglobal` | Campo FK | Campo para mostrar |
|-----------------|-----------------|----------|-------------------|
| `COUNTRY_CODE` | `global_country` | `iso_alpha2` | `name_common` / `name_native[locale]` |
| `LOCALE_BCP47` | `global_language` | `locale` | `name[locale]` (JSONB multilingüe) |
| `TIMEZONE_IANA` | `geo_timezone` | `timezone_id` | `name[locale]` + `utc_offset` |
| `MONEY` | `global_currency` | `currency_code` | `name[locale]` + `symbol` |

### 12.3 Políticas de validación para los tres nuevos formatos

```json
// COUNTRY_CODE — código ISO 3166-1 alpha-2 (verificado contra bglobal.global_country)
{
  "required": false,
  "regex": "^[A-Z]{2}$",
  "min_length": 2,
  "max_length": 2,
  "normalize": "uppercase",
  "unique_per_entity": false,
  "standard_ref": "ISO 3166-1 alpha-2 — bglobal.global_country.iso_alpha2"
}

// LOCALE_BCP47 — locale IETF BCP 47 (verificado contra bglobal.global_language)
{
  "required": false,
  "regex": "^[a-z]{2,3}(-[A-Z]{2,3})?(-[A-Za-z0-9]{4,8})?$",
  "min_length": 2,
  "max_length": 12,
  "normalize": "none",
  "unique_per_entity": false,
  "standard_ref": "IETF BCP 47 — bglobal.global_language.locale"
}

// TIMEZONE_IANA — identificador IANA tzdata (verificado contra bglobal.geo_timezone)
{
  "required": false,
  "regex": "^[A-Za-z_]+/[A-Za-z_/]+$",
  "min_length": 5,
  "max_length": 64,
  "normalize": "none",
  "unique_per_entity": false,
  "standard_ref": "IANA Timezone Database — bglobal.geo_timezone.timezone_id"
}
```

### 12.4 Mapeo corregido: UserTemplate v6.0 → `idn_atributo` + bglobal

Corrección al mapeo previsto para el campo `nationality` del UserTemplate:
el código propuesto `ISO_3166_1_A3` **queda descartado** — se usa `COUNTRY_CODE`
(alpha-2 de `bglobal.global_country`) porque la tabla usa alpha-2 como PK funcional.

| Campo UserTemplate | `category` | `attr_key` | `display_format` | FK bglobal |
|-------------------|------------|------------|-----------------|-----------|
| `basic.nationality` | `personal` | `nationality` | `COUNTRY_CODE` | `global_country.iso_alpha2` |
| `basic.locale` | `personal` | `locale` | `LOCALE_BCP47` | `global_language.locale` |
| `basic.zoneinfo` | `personal` | `timezone` | `TIMEZONE_IANA` | `geo_timezone.timezone_id` |
| `basic.national_id` | `documento` | `id_nacional` | `ID_XX` (alpha-2 país) | `global_country.iso_alpha2` para elegir el formato |
| `contact.phones[].number` | `contacto` | `telefono` | `E164` | `global_country.itu_calling_code` para el selector |
| `contact.emails[].address` | `contacto` | `email` | `EMAIL` | — |
| `addresses[].street+city` | `ubicacion` | `direccion` | `TEXTO_LIBRE` | — |
| `basic.birth_date` | `personal` | `birth_date` | `DATE_ISO` | — |
| `basic.gender` | `personal` | `gender` | `TEXTO_LIBRE` + `allowed_values` | — |
| `emergency_contacts[]` | `contacto` | `contacto_emergencia` | `TEXTO_LIBRE` | `value_data JSONB` |

### 12.5 Integración con `bcalendar` (horarios)

La tabla `bcalendar.cal_schedule` gestiona horarios de trabajo a nivel tenant:

| Columna clave | Descripción |
|--------------|-------------|
| `tenant_id` | Horario pertenece al tenant (o es global si NULL) |
| `days_of_week` | Array de días: `['MONDAY','TUESDAY'...]` |
| `start_time` / `end_time` | Horario base del turno |
| `shifts JSONB` | Turnos múltiples por día (mañana/tarde/noche) |
| `schedule_type` | `FULL_WEEK` / `SPECIFIC_DAYS` / `SHIFT_BASED` |

Para registrar el horario laboral de un actor en `idn_atributo`:
```
category    = 'profesional'
attr_key    = 'horario'
attr_subtype = 'laboral' | 'guardia' | 'turno_noche'
value_text  = NULL
value_data  = { "schedule_id": "<uuid de cal_schedule>",
                "timezone_id": "America/La_Paz",
                "overrides": {} }
display_format = 'TIMEZONE_IANA'  ← solo para mostrar la zona horaria del horario
```

### 12.6 Integración con `bauth.cfg_policy_library`

La tabla `bauth.cfg_policy_library` tiene **9,142 registros** organizados por dominio
(D1–D12, SEC) con campos `standard_ref`, `enforcement`, `risk_level`, `compliance_ref[]`.

Para el campo `validation_policy.standard_ref` de `idn_atributo`, los valores correctos
se toman de `cfg_policy_library.standard_ref` — no se inventan. Esto garantiza
trazabilidad normativa desde el atributo hasta la política de seguridad que lo rige.

Ejemplo de uso:
```sql
-- Qué estándar cubre el campo 'telefono' con formato E164:
SELECT standard_ref, compliance_ref, risk_level
FROM bauth.cfg_policy_library
WHERE domain_map @> '{D1}' AND standard_ref ILIKE '%E.164%'
LIMIT 3;
```

---

*Documento técnico de planificación — no requiere aprobación DDL por sí mismo.*
*La tabla `idn_atributo` requiere aprobación DDL formal antes de implementar (ADR-016).*
