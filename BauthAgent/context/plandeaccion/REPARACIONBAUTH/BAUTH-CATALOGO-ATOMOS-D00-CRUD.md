# BAUTH-CATALOGO-ATOMOS-D00-CRUD — Catálogo CRUD D00 Identidad Organizacional
## bAuth Identity Core v3.0 · Diseño — NO IMPLEMENTADO, pendiente aprobación DDL

**Versión:** 1.0.0 · **Fecha:** 2026-07-01 · **Estado:** DISEÑO APROBADO — DDL PENDIENTE

**Decisión arquitectónica:** CRUD completo por campo (4 átomos: C=CREATE, R=READ, U=UPDATE, D=DELETE).
Reemplaza los 20 átomos semánticos (verbos 51-63) por 108 átomos CRUD con granularidad máxima.

**Referencia:** `BAUTH-ARQUITECTURA-ATOMICA-FINAL.md §D00` · `BAUTH-D00-ATRIBUTO-EXTENSIBLE-v1.0.md`

---

## Semántica de verbos CRUD en contexto de identidad organizacional

| Verbo | Código | Semántica en D00 |
|-------|:------:|-----------------|
| **C** — CREATE | 1 | Crear la entidad / registrar el campo por primera vez |
| **R** — READ | 2 | Leer / visualizar el valor del campo |
| **U** — UPDATE | 3 | Modificar / actualizar el valor del campo |
| **D** — DELETE | 4 | Eliminar / limpiar el campo (para campos opcionales) |

> **Nota:** DELETE en campos ENUM obligatorios (type) significa "reset a valor por defecto" o
> capacidad de desactivar la entidad. DELETE en campos `idn_atributo` significa eliminar
> esa fila del atributo (ej: eliminar un email de la lista).

---

## Nomenclatura de átomos CRUD D00

```
D00.org.{entidad}_{campo}.{VERBO}

Donde:
  D00   = dominio 0 — Identidad Organizacional
  org   = aplicación (app_code = 13)
  {entidad}_{campo} = módulo compuesto (entidad + campo, snake_case)
  {VERBO} = C | R | U | D
```

---

## Posiciones en BD (privilege_atom)

Los 20 átomos semánticos originales (5809-5828) son **REEMPLAZADOS**.
Los 108 átomos CRUD ocupan posiciones **5809-5916**.

---

## Módulo: tenant (group_code = 1)

| Átomo | CRUD | pos BD | Storage | Estándar |
|-------|:----:|:------:|---------|---------|
| `D00.org.tenant_type.C` | CREATE | 5809 | columna `idn_tenant.type` | SBOS-MODEL-D00 |
| `D00.org.tenant_type.R` | READ   | 5810 | columna `idn_tenant.type` | SBOS-MODEL-D00 |
| `D00.org.tenant_type.U` | UPDATE | 5811 | columna `idn_tenant.type` | SBOS-MODEL-D00 |
| `D00.org.tenant_type.D` | DELETE | 5812 | columna `idn_tenant.type` (reset) | SBOS-MODEL-D00 |

**ENUM válidos tenant.type:** `interno` / `externo`

---

## Módulo: bdomain (group_code = 2)

### Campo: type

| Átomo | CRUD | pos BD | Storage | Estándar |
|-------|:----:|:------:|---------|---------|
| `D00.org.bdomain_type.C` | CREATE | 5813 | columna `org_empresa.tipo_bdomain` | ISO 9001:2015 §3.2.4 |
| `D00.org.bdomain_type.R` | READ   | 5814 | columna `org_empresa.tipo_bdomain` | ISO 9001:2015 §3.2.4 |
| `D00.org.bdomain_type.U` | UPDATE | 5815 | columna `org_empresa.tipo_bdomain` | ISO 9001:2015 §3.2.4 |
| `D00.org.bdomain_type.D` | DELETE | 5816 | columna `org_empresa.tipo_bdomain` (reset) | ISO 9001:2015 §3.2.4 |

**ENUM válidos bdomain.type:** `empresa` / `persona` / `hogar` / `desarrollador` / `m2m` / `edificio`

### Campo: nombre

| Átomo | CRUD | pos BD | Storage | Estándar |
|-------|:----:|:------:|---------|---------|
| `D00.org.bdomain_nombre.C` | CREATE | 5817 | columna `org_empresa.nombre` | ISO 24760-2:2025 §4.2 |
| `D00.org.bdomain_nombre.R` | READ   | 5818 | columna `org_empresa.nombre` | ISO 24760-2:2025 §4.2 |
| `D00.org.bdomain_nombre.U` | UPDATE | 5819 | columna `org_empresa.nombre` | ISO 24760-2:2025 §4.2 |
| `D00.org.bdomain_nombre.D` | DELETE | 5820 | columna `org_empresa.nombre` (N/A — required) | ISO 24760-2:2025 §4.2 |

### Campo: nit (tributario fiscal)

| Átomo | CRUD | pos BD | Storage | display_format | Estándar |
|-------|:----:|:------:|---------|:-------------:|---------|
| `D00.org.bdomain_nit.C` | CREATE | 5821 | `idn_atributo` (cat=documento, key=nit) | `TAX_XX` | ISO 3166-1 · SIN Bolivia |
| `D00.org.bdomain_nit.R` | READ   | 5822 | `idn_atributo` | `TAX_XX` | ISO 3166-1 · SIN Bolivia |
| `D00.org.bdomain_nit.U` | UPDATE | 5823 | `idn_atributo` | `TAX_XX` | ISO 3166-1 · SIN Bolivia |
| `D00.org.bdomain_nit.D` | DELETE | 5824 | `idn_atributo` (eliminar fila) | `TAX_XX` | ISO 3166-1 · SIN Bolivia |

> TAX_XX = código dinámico por país del tenant. Ej: TAX_BO=NIT, TAX_AR=CUIT, TAX_CL=RUT, TAX_BR_CNPJ, TAX_US_EIN

### Campo: email

| Átomo | CRUD | pos BD | Storage | display_format | Estándar |
|-------|:----:|:------:|---------|:-------------:|---------|
| `D00.org.bdomain_email.C` | CREATE | 5825 | `idn_atributo` (cat=contacto, key=email) | `EMAIL` | RFC 5321 |
| `D00.org.bdomain_email.R` | READ   | 5826 | `idn_atributo` | `EMAIL` | RFC 5321 |
| `D00.org.bdomain_email.U` | UPDATE | 5827 | `idn_atributo` | `EMAIL` | RFC 5321 |
| `D00.org.bdomain_email.D` | DELETE | 5828 | `idn_atributo` (eliminar fila) | `EMAIL` | RFC 5321 |

> Cardinalidad 1:N — un bDomain puede tener múltiples emails (contacto, facturación, soporte)

### Campo: telefono

| Átomo | CRUD | pos BD | Storage | display_format | Estándar |
|-------|:----:|:------:|---------|:-------------:|---------|
| `D00.org.bdomain_telefono.C` | CREATE | 5829 | `idn_atributo` (cat=contacto, key=telefono) | `E164` | ITU-T E.164 |
| `D00.org.bdomain_telefono.R` | READ   | 5830 | `idn_atributo` | `E164` | ITU-T E.164 |
| `D00.org.bdomain_telefono.U` | UPDATE | 5831 | `idn_atributo` | `E164` | ITU-T E.164 |
| `D00.org.bdomain_telefono.D` | DELETE | 5832 | `idn_atributo` (eliminar fila) | `E164` | ITU-T E.164 |

### Campo: ci (carnet/documento de identidad del bDomain persona)

| Átomo | CRUD | pos BD | Storage | display_format | Estándar |
|-------|:----:|:------:|---------|:-------------:|---------|
| `D00.org.bdomain_ci.C` | CREATE | 5833 | `idn_atributo` (cat=documento, key=id_doc) | `ID_XX` | ISO 3166-1 por país |
| `D00.org.bdomain_ci.R` | READ   | 5834 | `idn_atributo` | `ID_XX` | ISO 3166-1 por país |
| `D00.org.bdomain_ci.U` | UPDATE | 5835 | `idn_atributo` | `ID_XX` | ISO 3166-1 por país |
| `D00.org.bdomain_ci.D` | DELETE | 5836 | `idn_atributo` (eliminar fila) | `ID_XX` | ISO 3166-1 por país |

### Campo: direccion

| Átomo | CRUD | pos BD | Storage | display_format | Estándar |
|-------|:----:|:------:|---------|:-------------:|---------|
| `D00.org.bdomain_direccion.C` | CREATE | 5837 | `idn_atributo` (cat=ubicacion, key=direccion) | `TEXTO_LIBRE` | ISO 24760-2:2025 §6 |
| `D00.org.bdomain_direccion.R` | READ   | 5838 | `idn_atributo` | `TEXTO_LIBRE` | ISO 24760-2:2025 §6 |
| `D00.org.bdomain_direccion.U` | UPDATE | 5839 | `idn_atributo` | `TEXTO_LIBRE` | ISO 24760-2:2025 §6 |
| `D00.org.bdomain_direccion.D` | DELETE | 5840 | `idn_atributo` (eliminar fila) | `TEXTO_LIBRE` | ISO 24760-2:2025 §6 |

> Tipos de dirección (attr_subtype): work / fiscal / registered / home / shipping

---

## Módulo: bsubdomain (group_code = 3)

### Campo: type

| Átomo | CRUD | pos BD | Storage | Estándar |
|-------|:----:|:------:|---------|---------|
| `D00.org.bsubdomain_type.C` | CREATE | 5841 | columna `org_sucursal.tipo` | SBOS-MODEL-D00 |
| `D00.org.bsubdomain_type.R` | READ   | 5842 | columna `org_sucursal.tipo` | SBOS-MODEL-D00 |
| `D00.org.bsubdomain_type.U` | UPDATE | 5843 | columna `org_sucursal.tipo` | SBOS-MODEL-D00 |
| `D00.org.bsubdomain_type.D` | DELETE | 5844 | columna `org_sucursal.tipo` (reset) | SBOS-MODEL-D00 |

**ENUM válidos bsubdomain.type:** `sucursal` / `dependiente` / `familiar` / `oficina`

### Campo: nombre

| Átomo | CRUD | pos BD | Storage | Estándar |
|-------|:----:|:------:|---------|---------|
| `D00.org.bsubdomain_nombre.C` | CREATE | 5845 | columna `org_sucursal.nombre` | ISO 24760-2:2025 §4.2 |
| `D00.org.bsubdomain_nombre.R` | READ   | 5846 | columna `org_sucursal.nombre` | ISO 24760-2:2025 §4.2 |
| `D00.org.bsubdomain_nombre.U` | UPDATE | 5847 | columna `org_sucursal.nombre` | ISO 24760-2:2025 §4.2 |
| `D00.org.bsubdomain_nombre.D` | DELETE | 5848 | N/A — required | ISO 24760-2:2025 §4.2 |

### Campo: direccion

| Átomo | CRUD | pos BD | Storage | display_format | Estándar |
|-------|:----:|:------:|---------|:-------------:|---------|
| `D00.org.bsubdomain_direccion.C` | CREATE | 5849 | `idn_atributo` (cat=ubicacion, key=direccion) | `TEXTO_LIBRE` | SCIM 2.0 RFC 7643 |
| `D00.org.bsubdomain_direccion.R` | READ   | 5850 | `idn_atributo` | `TEXTO_LIBRE` | SCIM 2.0 RFC 7643 |
| `D00.org.bsubdomain_direccion.U` | UPDATE | 5851 | `idn_atributo` | `TEXTO_LIBRE` | SCIM 2.0 RFC 7643 |
| `D00.org.bsubdomain_direccion.D` | DELETE | 5852 | `idn_atributo` (eliminar fila) | `TEXTO_LIBRE` | SCIM 2.0 RFC 7643 |

---

## Módulo: pos (group_code = 4)

### Campo: type

| Átomo | CRUD | pos BD | Storage | Estándar |
|-------|:----:|:------:|---------|---------|
| `D00.org.pos_type.C` | CREATE | 5853 | columna `org_pos_logico.tipo` | SBOS-049 §6.1 |
| `D00.org.pos_type.R` | READ   | 5854 | columna `org_pos_logico.tipo` | SBOS-049 §6.1 |
| `D00.org.pos_type.U` | UPDATE | 5855 | columna `org_pos_logico.tipo` | SBOS-049 §6.1 |
| `D00.org.pos_type.D` | DELETE | 5856 | reset | SBOS-049 §6.1 |

**ENUM válidos pos.type:** `caja` / `terminal` / `puerta` / `sensor` / `actuador` / `punto_virtual`

### Campo: nombre

| Átomo | CRUD | pos BD | Storage | Estándar |
|-------|:----:|:------:|---------|---------|
| `D00.org.pos_nombre.C` | CREATE | 5857 | columna `org_pos_logico.nombre` | SBOS-049 §6.1 |
| `D00.org.pos_nombre.R` | READ   | 5858 | columna `org_pos_logico.nombre` | SBOS-049 §6.1 |
| `D00.org.pos_nombre.U` | UPDATE | 5859 | columna `org_pos_logico.nombre` | SBOS-049 §6.1 |
| `D00.org.pos_nombre.D` | DELETE | 5860 | N/A — required | SBOS-049 §6.1 |

---

## Módulo: actor (group_code = 5) — columnas directas

### Campo: type

| Átomo | CRUD | pos BD | Storage | Estándar |
|-------|:----:|:------:|---------|---------|
| `D00.org.actor_type.C` | CREATE | 5861 | columna `idn_user_template.actor_type` | SCIM 2.0 RFC 7643 §4.1 |
| `D00.org.actor_type.R` | READ   | 5862 | columna `idn_user_template.actor_type` | SCIM 2.0 RFC 7643 §4.1 |
| `D00.org.actor_type.U` | UPDATE | 5863 | columna `idn_user_template.actor_type` | SCIM 2.0 RFC 7643 §4.1 |
| `D00.org.actor_type.D` | DELETE | 5864 | reset a `HUMAN` | SCIM 2.0 RFC 7643 §4.1 |

**ENUM válidos actor.type:** `HUMAN` / `SERVICE` / `DEVICE` / `BOT`

### Campo: employee_type

| Átomo | CRUD | pos BD | Storage | Estándar |
|-------|:----:|:------:|---------|---------|
| `D00.org.actor_employee_type.C` | CREATE | 5865 | columna `idn_user_template.employee_type` | SCIM Enterprise §4.3 |
| `D00.org.actor_employee_type.R` | READ   | 5866 | columna `idn_user_template.employee_type` | SCIM Enterprise §4.3 |
| `D00.org.actor_employee_type.U` | UPDATE | 5867 | columna `idn_user_template.employee_type` | SCIM Enterprise §4.3 |
| `D00.org.actor_employee_type.D` | DELETE | 5868 | reset a `NONE` | SCIM Enterprise §4.3 |

**ENUM válidos:** `FULL_TIME` / `PART_TIME` / `CONTRACTOR` / `INTERN` / `NONE` / `STUDENT`

### Campo: gender

| Átomo | CRUD | pos BD | Storage | Estándar |
|-------|:----:|:------:|---------|---------|
| `D00.org.actor_gender.C` | CREATE | 5869 | columna `idn_user_template.gender` | SCIM 2.0 RFC 7643 §4.1.2 |
| `D00.org.actor_gender.R` | READ   | 5870 | columna `idn_user_template.gender` | SCIM 2.0 RFC 7643 §4.1.2 |
| `D00.org.actor_gender.U` | UPDATE | 5871 | columna `idn_user_template.gender` | SCIM 2.0 RFC 7643 §4.1.2 |
| `D00.org.actor_gender.D` | DELETE | 5872 | reset a `NR` (Not Reported) | SCIM 2.0 RFC 7643 §4.1.2 |

**ENUM válidos:** `M` / `F` / `NB` / `NR`

### Campo: marital_status

| Átomo | CRUD | pos BD | Storage | Estándar |
|-------|:----:|:------:|---------|---------|
| `D00.org.actor_marital_status.C` | CREATE | 5873 | columna `idn_user_template.marital_status` | ISO 24760-2:2025 §4.3 |
| `D00.org.actor_marital_status.R` | READ   | 5874 | columna `idn_user_template.marital_status` | ISO 24760-2:2025 §4.3 |
| `D00.org.actor_marital_status.U` | UPDATE | 5875 | columna `idn_user_template.marital_status` | ISO 24760-2:2025 §4.3 |
| `D00.org.actor_marital_status.D` | DELETE | 5876 | reset a NULL | ISO 24760-2:2025 §4.3 |

**ENUM válidos:** `SINGLE` / `MARRIED` / `DIVORCED` / `WIDOWED` / `CIVIL_UNION`

### Campo: id_doc_type

| Átomo | CRUD | pos BD | Storage | Estándar |
|-------|:----:|:------:|---------|---------|
| `D00.org.actor_id_doc_type.C` | CREATE | 5877 | columna `idn_user_template.id_doc_type` | ISO 3166-1 por país |
| `D00.org.actor_id_doc_type.R` | READ   | 5878 | columna `idn_user_template.id_doc_type` | ISO 3166-1 por país |
| `D00.org.actor_id_doc_type.U` | UPDATE | 5879 | columna `idn_user_template.id_doc_type` | ISO 3166-1 por país |
| `D00.org.actor_id_doc_type.D` | DELETE | 5880 | reset a `NONE` | ISO 3166-1 por país |

**ENUM dinámico por país:** `CI` / `DNI` / `CC` / `DUI` / `CURP` / `CPF` / `RG` / `PASSPORT` / `NONE`

### Campo: locale

| Átomo | CRUD | pos BD | Storage | display_format | Estándar |
|-------|:----:|:------:|---------|:-------------:|---------|
| `D00.org.actor_locale.C` | CREATE | 5881 | columna `idn_user_template.locale` | `LOCALE_BCP47` | IETF BCP 47 |
| `D00.org.actor_locale.R` | READ   | 5882 | columna `idn_user_template.locale` | `LOCALE_BCP47` | IETF BCP 47 |
| `D00.org.actor_locale.U` | UPDATE | 5883 | columna `idn_user_template.locale` | `LOCALE_BCP47` | IETF BCP 47 |
| `D00.org.actor_locale.D` | DELETE | 5884 | reset a tenant default locale | IETF BCP 47 |

> Validado contra `bglobal.global_language.locale` — 125 idiomas

### Campo: timezone

| Átomo | CRUD | pos BD | Storage | display_format | Estándar |
|-------|:----:|:------:|---------|:-------------:|---------|
| `D00.org.actor_timezone.C` | CREATE | 5885 | columna `idn_user_template.timezone` | `TIMEZONE_IANA` | IANA tzdata |
| `D00.org.actor_timezone.R` | READ   | 5886 | columna `idn_user_template.timezone` | `TIMEZONE_IANA` | IANA tzdata |
| `D00.org.actor_timezone.U` | UPDATE | 5887 | columna `idn_user_template.timezone` | `TIMEZONE_IANA` | IANA tzdata |
| `D00.org.actor_timezone.D` | DELETE | 5888 | reset a tenant default timezone | IANA tzdata |

> Validado contra `bglobal.geo_timezone.timezone_id` — 319 zonas

---

## Módulo: actor (group_code = 5) — campos idn_atributo

### Campo: birth_date

| Átomo | CRUD | pos BD | Storage | display_format | Estándar |
|-------|:----:|:------:|---------|:-------------:|---------|
| `D00.org.actor_birth_date.C` | CREATE | 5889 | `idn_atributo` (cat=personal, key=birth_date) | `DATE_ISO` | ISO 8601 · NIST SP 800-63A §5.3 |
| `D00.org.actor_birth_date.R` | READ   | 5890 | `idn_atributo` | `DATE_ISO` | ISO 8601 |
| `D00.org.actor_birth_date.U` | UPDATE | 5891 | `idn_atributo` | `DATE_ISO` | ISO 8601 |
| `D00.org.actor_birth_date.D` | DELETE | 5892 | eliminar fila | ISO 8601 |

### Campo: nationality

| Átomo | CRUD | pos BD | Storage | display_format | Estándar |
|-------|:----:|:------:|---------|:-------------:|---------|
| `D00.org.actor_nationality.C` | CREATE | 5893 | `idn_atributo` (cat=personal, key=nationality) | `COUNTRY_CODE` | ISO 3166-1 alpha-2 |
| `D00.org.actor_nationality.R` | READ   | 5894 | `idn_atributo` | `COUNTRY_CODE` | ISO 3166-1 alpha-2 |
| `D00.org.actor_nationality.U` | UPDATE | 5895 | `idn_atributo` | `COUNTRY_CODE` | ISO 3166-1 alpha-2 |
| `D00.org.actor_nationality.D` | DELETE | 5896 | eliminar fila | ISO 3166-1 alpha-2 |

> Valor almacenado: 2 letras (ej: `BO`). Frontend resuelve nombre desde `bglobal.global_country`

### Campo: id_doc_number (número de documento de identidad)

| Átomo | CRUD | pos BD | Storage | display_format | Estándar |
|-------|:----:|:------:|---------|:-------------:|---------|
| `D00.org.actor_id_doc_number.C` | CREATE | 5897 | `idn_atributo` (cat=documento, key=id_doc) | `ID_XX` | ISO 3166-1 por país |
| `D00.org.actor_id_doc_number.R` | READ   | 5898 | `idn_atributo` — campo sensible: puede enmascararse | `ID_XX` | ISO 3166-1 por país |
| `D00.org.actor_id_doc_number.U` | UPDATE | 5899 | `idn_atributo` | `ID_XX` | ISO 3166-1 por país |
| `D00.org.actor_id_doc_number.D` | DELETE | 5900 | eliminar fila | ISO 3166-1 por país |

> READ sin este átomo → campo oculto en UI (protección de datos personales, GDPR Art. 9)

### Campo: email (del actor individual)

| Átomo | CRUD | pos BD | Storage | display_format | Estándar |
|-------|:----:|:------:|---------|:-------------:|---------|
| `D00.org.actor_email.C` | CREATE | 5901 | `idn_atributo` (cat=contacto, key=email) | `EMAIL` | RFC 5321 · SCIM 2.0 §4.1 |
| `D00.org.actor_email.R` | READ   | 5902 | `idn_atributo` | `EMAIL` | RFC 5321 |
| `D00.org.actor_email.U` | UPDATE | 5903 | `idn_atributo` | `EMAIL` | RFC 5321 |
| `D00.org.actor_email.D` | DELETE | 5904 | eliminar fila | RFC 5321 |

### Campo: telefono (del actor individual)

| Átomo | CRUD | pos BD | Storage | display_format | Estándar |
|-------|:----:|:------:|---------|:-------------:|---------|
| `D00.org.actor_telefono.C` | CREATE | 5905 | `idn_atributo` (cat=contacto, key=telefono) | `E164` | ITU-T E.164 |
| `D00.org.actor_telefono.R` | READ   | 5906 | `idn_atributo` | `E164` | ITU-T E.164 |
| `D00.org.actor_telefono.U` | UPDATE | 5907 | `idn_atributo` | `E164` | ITU-T E.164 |
| `D00.org.actor_telefono.D` | DELETE | 5908 | eliminar fila | ITU-T E.164 |

### Campo: direccion (del actor individual)

| Átomo | CRUD | pos BD | Storage | display_format | Estándar |
|-------|:----:|:------:|---------|:-------------:|---------|
| `D00.org.actor_direccion.C` | CREATE | 5909 | `idn_atributo` (cat=ubicacion, key=direccion) | `TEXTO_LIBRE` | SCIM 2.0 RFC 7643 §4.1 |
| `D00.org.actor_direccion.R` | READ   | 5910 | `idn_atributo` | `TEXTO_LIBRE` | SCIM 2.0 RFC 7643 §4.1 |
| `D00.org.actor_direccion.U` | UPDATE | 5911 | `idn_atributo` | `TEXTO_LIBRE` | SCIM 2.0 RFC 7643 §4.1 |
| `D00.org.actor_direccion.D` | DELETE | 5912 | eliminar fila | SCIM 2.0 RFC 7643 §4.1 |

### Campo: photo

| Átomo | CRUD | pos BD | Storage | display_format | Estándar |
|-------|:----:|:------:|---------|:-------------:|---------|
| `D00.org.actor_photo.C` | CREATE | 5913 | `idn_atributo` (cat=personal, key=photo_url) | `URL_HTTPS` | SCIM 2.0 RFC 7643 §4.1.2 |
| `D00.org.actor_photo.R` | READ   | 5914 | `idn_atributo` | `URL_HTTPS` | SCIM 2.0 RFC 7643 §4.1.2 |
| `D00.org.actor_photo.U` | UPDATE | 5915 | `idn_atributo` | `URL_HTTPS` | SCIM 2.0 RFC 7643 §4.1.2 |
| `D00.org.actor_photo.D` | DELETE | 5916 | eliminar fila | SCIM 2.0 RFC 7643 §4.1.2 |

### Campo: bio

| Átomo | CRUD | pos BD | Storage | display_format | Estándar |
|-------|:----:|:------:|---------|:-------------:|---------|
| `D00.org.actor_bio.C` | CREATE | 5917 | `idn_atributo` (cat=personal, key=bio) | `TEXTO_LIBRE` | SCIM 2.0 §4.1 |
| `D00.org.actor_bio.R` | READ   | 5918 | `idn_atributo` | `TEXTO_LIBRE` | SCIM 2.0 §4.1 |
| `D00.org.actor_bio.U` | UPDATE | 5919 | `idn_atributo` | `TEXTO_LIBRE` | SCIM 2.0 §4.1 |
| `D00.org.actor_bio.D` | DELETE | 5920 | eliminar fila | SCIM 2.0 §4.1 |

---

## Módulo: actor — Professional (group_code = 5, campos de BLOQUE 3)

### Campo: department

| Átomo | CRUD | pos BD | Storage | display_format | Estándar |
|-------|:----:|:------:|---------|:-------------:|---------|
| `D00.org.actor_department.C` | CREATE | 5921 | `idn_atributo` (cat=profesional, key=departamento) | `TEXTO_LIBRE` | SCIM Enterprise §4.3 |
| `D00.org.actor_department.R` | READ   | 5922 | `idn_atributo` | `TEXTO_LIBRE` | SCIM Enterprise §4.3 |
| `D00.org.actor_department.U` | UPDATE | 5923 | `idn_atributo` | `TEXTO_LIBRE` | SCIM Enterprise §4.3 |
| `D00.org.actor_department.D` | DELETE | 5924 | eliminar fila | SCIM Enterprise §4.3 |

### Campo: title (cargo profesional)

| Átomo | CRUD | pos BD | Storage | display_format | Estándar |
|-------|:----:|:------:|---------|:-------------:|---------|
| `D00.org.actor_title.C` | CREATE | 5925 | `idn_atributo` (cat=profesional, key=cargo) | `TEXTO_LIBRE` | SCIM Enterprise §4.3 |
| `D00.org.actor_title.R` | READ   | 5926 | `idn_atributo` | `TEXTO_LIBRE` | SCIM Enterprise §4.3 |
| `D00.org.actor_title.U` | UPDATE | 5927 | `idn_atributo` | `TEXTO_LIBRE` | SCIM Enterprise §4.3 |
| `D00.org.actor_title.D` | DELETE | 5928 | eliminar fila | SCIM Enterprise §4.3 |

---

## Resumen del catálogo D00 CRUD

| Módulo | Campos | Átomos | Rango posiciones |
|--------|:------:|:------:|:----------------:|
| tenant | 1 | 4 | 5809–5812 |
| bdomain | 7 | 28 | 5813–5840 |
| bsubdomain | 3 | 12 | 5841–5852 |
| pos | 2 | 8 | 5853–5860 |
| actor (columnas) | 7 | 28 | 5861–5888 |
| actor (idn_atributo — personal) | 7 | 28 | 5889–5916 |
| actor (idn_atributo — bio) | 1 | 4 | 5917–5920 |
| actor (idn_atributo — profesional) | 2 | 8 | 5921–5928 |
| **TOTAL D00** | **30** | **120** | **5809–5928** |

> **120 átomos** (30 campos × 4 CRUD) — rango 5809-5928.
> Los 20 átomos semánticos originales (5809-5828) son REEMPLAZADOS por este catálogo.

---

## Ejemplos de asignación por rol

| Rol | Átomos concedidos | Capacidad |
|-----|-------------------|-----------|
| **AUDITORIA_LECTURA** | todos los `.R` (30 átomos) | Ve todo, no puede modificar nada |
| **RR_HH_OPERADOR** | actor_*.C + actor_*.R + actor_*.U (sin DELETE) | Gestiona actores, no puede borrar |
| **ADMIN_EMPRESA** | bdomain_*.C+R+U+D + bsubdomain_*.C+R+U+D | Gestiona su empresa y sucursales |
| **SUPER_ADMIN** | todos los 120 átomos | Control total D00 |
| **SELF_SERVICE** | actor_photo.U + actor_bio.U + actor_telefono.U | Usuario edita solo su perfil público |
| **COMPLIANCE_GDPR** | actor_id_doc_number.D + actor_birth_date.D | Puede ejecutar "derecho al olvido" |

---

*Documento de diseño — pendiente aprobación DDL antes de implementar.*

---

## ACLARACIÓN CONCEPTUAL — El CRUD y el problema del huevo y la gallina
**Fecha:** 2026-07-06 · **Origen:** sesión de revisión con Iván (HITL)

### Pregunta planteada

> "Cuando hemos hablado de CRUD hemos hablado en el sentido de que los verbos también
> deberían contemplar el CRUD para el motor BitMask — si el usuario operador puede en
> cada átomo crear, modificar, leer o borrar ese átomo, no es otra cosa. Pero creo que
> se distorsionó el concepto. La estructura de átomo debe poder dar la posibilidad al
> usuario en el momento de actualizar el árbol de configuraciones de poder controlar
> esas operaciones de cada átomo en el árbol. ¿Cómo se administrarán esos privilegios?
> El mismo árbol del template del rol se llenaría de repeticiones de átomos para definir
> a cuáles tiene acceso un rol y definir las operaciones que puede efectuar sobre esos
> átomos. Es como el problema del huevo o la gallina."

### Clarificación — Dos niveles de CRUD distintos

El catálogo mezcla dos conceptos que deben distinguirse:

#### Nivel 1 — CRUD sobre el DATO (lo que hace este catálogo)

Controla qué puede hacer un usuario con los **datos organizacionales** (NIT, email, CI…):

```
D00.org.bdomain_nit.C  → este rol puede REGISTRAR un NIT en la empresa
D00.org.bdomain_nit.R  → este rol puede LEER el NIT
D00.org.bdomain_nit.U  → este rol puede MODIFICAR el NIT
D00.org.bdomain_nit.D  → este rol puede BORRAR el NIT
```

Es la pregunta: "¿qué puede hacer el usuario final con los datos que protege este átomo?"
Estándar: AWS IAM (`s3:GetObject`, `s3:PutObject`), NIST RBAC (permission = operación + objeto).

#### Nivel 2 — CRUD sobre la ASIGNACIÓN en el árbol (lo que Iván describió)

Controla qué puede hacer un admin con la **configuración del árbol de roles**:

```
D1.bauth.role_config.CREATE → este admin puede AGREGAR átomos a un rol
D1.bauth.role_config.READ   → este admin puede VER la configuración de un rol
D1.bauth.role_config.UPDATE → este admin puede CAMBIAR valores de átomos en un rol
D1.bauth.role_config.DELETE → este admin puede QUITAR átomos de un rol
```

Es la pregunta: "¿quién puede modificar el árbol de configuración de roles?"
Estos átomos NO están en este catálogo — pertenecen al dominio D1 (Acceso Lógico, módulo bauth).

### El problema del huevo y la gallina — y su solución

El paradox: para asignar `D1.bauth.role_config.CREATE` a un rol admin, necesito
ser alguien con permiso de hacer esa asignación — pero ¿quién tiene ese permiso,
y cómo lo obtuvo?

**La solución universal de la industria: existe un nivel raíz FUERA del sistema de átomos.**

| Sistema | Raíz que no pasa por el sistema de permisos |
|---|---|
| Linux | `root` (uid=0) — el kernel no verifica sus permisos |
| PostgreSQL | Superuser — el código dice: `if (superuser()) return;` |
| AWS | Root account — está por encima de IAM, no le aplica |
| Keycloak | Realm `admin` — pre-provisionado por el instalador |
| **SBOS / bAuth** | **Tier SU** — provisionado por BOS al instalar, fuera del motor de átomos |

```
BOS installer (fuera del sistema de átomos — es el origen)
    │
    └── crea: SU (sin restricciones atómicas — ES la raíz)
                │
                └── asigna D1.bauth.role_config.* a IAM_ADMIN
                              │
                              └── IAM_ADMIN configura el resto de los roles
```

El árbol siempre tiene un techo que no se refleja sobre sí mismo. La recursión
termina en SU, que es creado por el instalador (BOS), no por el sistema de átomos.

### El problema del árbol con repeticiones — y su solución

Un rol complejo podría tener cientos de átomos asignados individualmente. La solución
son dos mecanismos ya diseñados en bAuth:

**Herencia DAG**: El rol HR_ADMIN hereda de STAFF. STAFF ya tiene los átomos básicos.
HR_ADMIN solo declara los átomos ADICIONALES que lo distinguen. El árbol visible es pequeño.

```
STAFF:    [D00.actor_email.R] [D00.actor_ci.R] [D1.tryton.personal.READ]
HR_ADMIN: hereda STAFF + [D00.actor_email.U] [D00.actor_ci.U] [D1.bauth.role_config.READ]
```

**idn_role_template como vista organizada**: El template no es una lista plana de átomos.
Es la vista en bloques que ve el admin en el dashboard. Los átomos viven en la BD;
el template los organiza en secciones legibles:

```
Template HR_ADMIN — vista del dashboard:
  Bloque "Datos de Actor":    [_][R][U][_]   ← no puede crear ni borrar actores
  Bloque "Configurar Roles":  [_][R][_][_]   ← solo puede ver configuraciones
  Bloque "Finanzas":          [_][_][_][_]   ← sin acceso
```

El admin ve secciones con sus capacidades. El BitMask tiene los bits individuales.
No hay repetición en el dashboard — hay granularidad en la BD.

### Conclusión — Qué hace este catálogo y qué falta

| Concepto | ¿Está en este catálogo? | ¿Dónde va? |
|---|:---:|---|
| CRUD sobre datos organizacionales (NIT, email, CI…) | ✅ SÍ | Aquí — D00, 108 átomos |
| CRUD sobre el árbol de configuración de roles | ❌ NO | D1.bauth.role_config.* — pendiente diseñar |
| Raíz de bootstrapping (SU sin átomos) | ❌ NO en este doc | BOS installer + idn_role_template tier SU |

**Tarea pendiente:** diseñar los átomos `D1.bauth.role_config.*` en el catálogo D1-D3
que controlan quién puede administrar el árbol de configuración de roles y usuarios.
*Ver: `BAUTH-D00-ATRIBUTO-EXTENSIBLE-v1.0.md` · `BAUTH-ARQUITECTURA-ATOMICA-FINAL.md`*
