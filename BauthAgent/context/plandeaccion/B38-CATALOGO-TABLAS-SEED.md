# B38 — CATÁLOGO DE TABLAS PARA CARGA DE DATOS MAESTROS
## Tablas que requieren seed data + estructura de campos + ejemplos
### SKULL · SBOS · Junio 2026

**Propósito:** Listado completo de tablas y campos que requieren datos iniciales (seed data) para que bAuth opere. Usar este documento para generar CSVs y luego cargarlos vía `bauthctl seed import`.

---

## 1. bos_pais — Países (ISO 3166-1)

| Campo | Tipo | Obligatorio | Descripción | Ejemplo |
|-------|------|------------|-------------|--------|
| `codice_iso` | CHAR(2) | ✅ PK | Código ISO 3166-1 alpha-2 | `BO` |
| `nombre` | TEXT | ✅ | Nombre del país en español | `Bolivia` |
| `gentilicio` | TEXT | | Gentilicio | `Boliviano/a` |
| `activo` | BOOLEAN | | País activo en el sistema | `true` |

**CSV esperado:** `bos_pais.csv`
```csv
codice_iso,nombre,gentilicio,activo
BO,Bolivia,Boliviano/a,true
AR,Argentina,Argentino/a,true
BR,Brasil,Brasileño/a,true
CL,Chile,Chileno/a,true
CO,Colombia,Colombiano/a,true
EC,Ecuador,Ecuatoriano/a,true
MX,Mexico,Mexicano/a,true
PE,Peru,Peruano/a,true
PY,Paraguay,Paraguayo/a,true
UY,Uruguay,Uruguayo/a,true
US,Estados Unidos,Estadounidense,false
ES,España,Español/a,false
```

---

## 2. bos_ciudad — Ciudades

| Campo | Tipo | Obligatorio | Descripción | Ejemplo |
|-------|------|------------|-------------|--------|
| `ciudad_id` | BIGSERIAL | ✅ PK | Auto-incremental | — |
| `nombre` | TEXT | ✅ | Nombre de la ciudad | `La Paz` |
| `pais_iso` | CHAR(2) | ✅ FK→bos_pais | País al que pertenece | `BO` |
| `activo` | BOOLEAN | | Ciudad activa | `true` |

**CSV esperado:** `bos_ciudad.csv`
```csv
nombre,pais_iso,activo
La Paz,BO,true
Santa Cruz de la Sierra,BO,true
Cochabamba,BO,true
El Alto,BO,true
Sucre,BO,true
Tarija,BO,true
Potosí,BO,true
Oruro,BO,true
Trinidad,BO,true
Cobija,BO,true
```

---

## 3. bos_moneda — Monedas (ISO 4217)

| Campo | Tipo | Obligatorio | Descripción | Ejemplo |
|-------|------|------------|-------------|--------|
| `codice_iso` | CHAR(3) | ✅ PK | Código ISO 4217 | `BOB` |
| `nombre` | TEXT | ✅ | Nombre de la moneda | `Boliviano` |
| `simbolo` | TEXT | | Símbolo | `Bs.` |
| `activo` | BOOLEAN | | Moneda activa | `true` |

**CSV esperado:** `bos_moneda.csv`
```csv
codice_iso,nombre,simbolo,activo
BOB,Boliviano,Bs.,true
USD,Dólar estadounidense,$,true
EUR,Euro,€,true
ARS,Peso argentino,AR$,true
BRL,Real brasileño,R$,true
CLP,Peso chileno,CLP$,true
COP,Peso colombiano,COL$,true
PEN,Sol peruano,S/,true
USDT,Tether USD,USD₮,true
```

---

## 4. bos_idioma — Idiomas (ISO 639-1)

| Campo | Tipo | Obligatorio | Descripción | Ejemplo |
|-------|------|------------|-------------|--------|
| `codigo` | CHAR(2) | ✅ PK | Código ISO 639-1 | `ES` |
| `nombre` | TEXT | ✅ | Nombre del idioma | `Español` |
| `activo` | BOOLEAN | | Idioma activo | `true` |

**CSV esperado:** `bos_idioma.csv`
```csv
codigo,nombre,activo
ES,Español,true
EN,Inglés,true
PT,Portugués,false
QU,Quechua,false
AY,Aymara,false
```

---

## 5. bos_timezone — Zonas Horarias

| Campo | Tipo | Obligatorio | Descripción | Ejemplo |
|-------|------|------------|-------------|--------|
| `timezone_id` | SERIAL | ✅ PK | Auto-incremental | — |
| `name` | TEXT | ✅ | Nombre IANA de la zona horaria | `America/La_Paz` |
| `utc_offset` | INTERVAL | ✅ | Offset UTC | `-04:00:00` |
| `country_code` | CHAR(2) | | País asociado | `BO` |

**CSV esperado:** `bos_timezone.csv`
```csv
name,utc_offset,country_code
America/La_Paz,-04:00:00,BO
America/New_York,-05:00:00,US
America/Sao_Paulo,-03:00:00,BR
Europe/Madrid,01:00:00,ES
America/Argentina/Buenos_Aires,-03:00:00,AR
America/Santiago,-04:00:00,CL
America/Lima,-05:00:00,PE
America/Bogota,-05:00:00,CO
America/Mexico_City,-06:00:00,MX
```

---

## 6. bos_credential_policy — Políticas de Credenciales por Tier

| Campo | Tipo | Obligatorio | Descripción | Ejemplo |
|-------|------|------------|-------------|--------|
| `policy_id` | BIGSERIAL | ✅ PK | Auto-incremental | — |
| `tenant_id` | TEXT | ✅ FK→bos_tenant | Tenant al que aplica | `skull` |
| `tier` | TEXT | ✅ | SU, SYS, BIZ, EXT, M2M | `SU` |
| `min_length` | INTEGER | | Longitud mínima de contraseña | `20` |
| `require_mfa` | BOOLEAN | | MFA obligatorio | `true` |
| `mfa_methods` | TEXT[] | | Métodos MFA permitidos | `{FIDO2}` |
| `password_ttl_days` | INTEGER | | Días de expiración (0=no expira) | `365` |

**CSV esperado:** `bos_credential_policy.csv`
```csv
tenant_id,tier,min_length,require_mfa,mfa_methods,password_ttl_days
skull,SU,20,true,"{FIDO2, TOTP}",365
skull,SYS,15,true,"{TOTP, FIDO2, PASSKEY}",365
skull,BIZ,12,false,,0
skull,EXT,8,false,,0
skull,M2M,0,false,,0
```
**Nota:** M2M no usa password — usa mTLS. `min_length=0` + `require_mfa=false`.

---

## 7. bos_financial_tipo_transaccion — Tipos de Transacción Financiera

| Campo | Tipo | Obligatorio | Descripción | Ejemplo |
|-------|------|------------|-------------|--------|
| `tipo_id` | TEXT | ✅ PK | Código único del tipo | `PAGO` |
| `nombre` | TEXT | ✅ | Nombre legible | `Pago a Proveedor` |
| `descripcion` | TEXT | | Descripción detallada | |
| `activo` | BOOLEAN | | Tipo activo | `true` |

**CSV esperado:** `bos_financial_tipo_transaccion.csv`
```csv
tipo_id,nombre,descripcion,activo
PAGO,Pago a Proveedor,Pago de facturas y servicios,true
TRANSFERENCIA,Transferencia entre Cuentas,Transferencia interna,true
REEMBOLSO,Reembolso de Gastos,Reembolso a empleados,true
ANTICIPO,Anticipo,Adelanto de fondos,true
LIQUIDACION,Liquidación,Transacción on-chain (D12-B),true
AJUSTE,Ajuste Contable,Corrección de saldos,true
COMISION,Comisión,Comisión por servicio,true
NC,Nota de Crédito,Devolución o descuento,true
ND,Nota de Débito,Cargo adicional,true
```

---

## 8. bos_gestion — Períodos Fiscales

| Campo | Tipo | Obligatorio | Descripción | Ejemplo |
|-------|------|------------|-------------|--------|
| `gestion_id` | BIGSERIAL | ✅ PK | Auto-incremental | — |
| `tenant_id` | TEXT | ✅ FK→bos_tenant | Tenant | `skull` |
| `nombre` | TEXT | ✅ | Nombre de la gestión | `Gestión 2026` |
| `fecha_inicio` | DATE | ✅ | Inicio del período | `2026-01-01` |
| `fecha_fin` | DATE | ✅ | Fin del período | `2026-12-31` |
| `activo` | BOOLEAN | | Gestión activa | `true` |

**CSV esperado:** `bos_gestion.csv`
```csv
tenant_id,nombre,fecha_inicio,fecha_fin,activo
skull,Gestión 2026,2026-01-01,2026-12-31,true
skull,Gestión 2027,2027-01-01,2027-12-31,false
```

---

## 9. bos_gestion_calendario — Feriados y Días Laborales

| Campo | Tipo | Obligatorio | Descripción | Ejemplo |
|-------|------|------------|-------------|--------|
| `calendario_id` | BIGSERIAL | ✅ PK | Auto-incremental | — |
| `gestion_id` | BIGINT | ✅ FK→bos_gestion | Gestión | `1` |
| `fecha` | DATE | ✅ | Fecha del día | `2026-01-01` |
| `tipo` | TEXT | ✅ | LABORAL, FERIADO_NACIONAL, FERIADO_REGIONAL, NO_LABORAL | `FERIADO_NACIONAL` |
| `descripcion` | TEXT | | Nombre del feriado | `Año Nuevo` |

**CSV esperado:** `bos_gestion_calendario.csv`
```csv
gestion_id,fecha,tipo,descripcion
1,2026-01-01,FERIADO_NACIONAL,Año Nuevo
1,2026-01-22,FERIADO_NACIONAL,Día del Estado Plurinacional
1,2026-02-16,FERIADO_NACIONAL,Carnaval (Lunes)
1,2026-02-17,FERIADO_NACIONAL,Carnaval (Martes)
1,2026-04-03,FERIADO_NACIONAL,Viernes Santo
1,2026-05-01,FERIADO_NACIONAL,Día del Trabajo
1,2026-06-21,FERIADO_NACIONAL,Año Nuevo Andino
1,2026-08-06,FERIADO_NACIONAL,Día de la Independencia
1,2026-11-01,FERIADO_NACIONAL,Todos los Santos
1,2026-12-25,FERIADO_NACIONAL,Navidad
```
**Nota:** No se listan todos los días LABORAL — solo los FERIADO_NACIONAL, FERIADO_REGIONAL y NO_LABORAL. Los días sin entrada se asumen LABORAL.

---

## 10. bos_sod_conflict_matrix — Conflictos SoD

| Campo | Tipo | Obligatorio | Descripción | Ejemplo |
|-------|------|------------|-------------|--------|
| `conflict_id` | BIGSERIAL | ✅ PK | Auto-incremental | — |
| `role_a` | TEXT | ✅ | ID del primer rol | `ROL-CAJERO` |
| `role_b` | TEXT | ✅ | ID del segundo rol | `ROL-AUDITOR` |
| `severity` | TEXT | ✅ | LOW, MEDIUM, HIGH, CRITICAL | `HIGH` |
| `description` | TEXT | | Descripción del conflicto | |

**CSV esperado:** `bos_sod_conflict_matrix.csv`
```csv
role_a,role_b,severity,description
ROL-FINANCIAL-CREATE,ROL-FINANCIAL-APPROVE,HIGH,"Crear y aprobar transacciones no pueden coexistir"
ROL-CAJERO,ROL-AUDITOR,HIGH,"Cajero no puede auditar su propia caja"
ROL-DESARROLLADOR,ROL-REVISOR-ROL,MEDIUM,"Desarrollador no puede revisar su propio código de rol"
ROL-COMPRADOR,ROL-APROBADOR-PAGO,HIGH,"Comprador no puede aprobar pagos a proveedores"
ROL-ADMIN-SEGURIDAD,ROL-ADMIN-TENANT,MEDIUM,"Seguridad y administración de tenant deben separarse"
ROL-CREADOR-FACTURA,ROL-ANULADOR-FACTURA,Critical,"Crear y anular facturas no pueden coexistir"
```

---

## 11. bos_tenant — Tenant Inicial SKULL

| Campo | Tipo | Obligatorio | Ejemplo |
|-------|------|------------|--------|
| `tenant_id` | TEXT | ✅ PK | `skull` |
| `nombre` | TEXT | ✅ | `SKULL Desarrollo de Software` |
| `tenant_type` | TEXT | ✅ (STANDARD/REGULATED/HIGH_SENSITIVITY) | `STANDARD` |
| `status` | TEXT | ✅ (PENDING_VERIFICATION/ACTIVE/SUSPENDED/TERMINATED) | `ACTIVE` |
| `verification_status` | TEXT | ✅ | `VERIFIED` |
| `legal_name` | TEXT | | `SKULL Desarrollo de Software S.R.L.` |
| `tax_id` | TEXT | | NIT Bolivia |
| `country` | TEXT | ✅ | `BO` |
| `realm_kc` | TEXT | ✅ UNIQUE | `skull` |
| `realm_kc_ext` | TEXT | ✅ UNIQUE | `skull-ext` |
| `namespace_k8s` | TEXT | ✅ UNIQUE | `sbos-system` |
| `domain` | TEXT | | `skull.sbos.skull.bo` |
| `isolation_level` | TEXT | ✅ | `SCHEMA_PER_TENANT` |
| `mfa_required` | BOOLEAN | ✅ | `false` |
| `password_policy` | TEXT | ✅ | `length(12)_argon2id_t3_m64` |
| `session_ttl_max` | INTEGER | ✅ | `28800` |
| `token_ttl_seconds` | INTEGER | ✅ | `3600` |
| `audit_level` | TEXT | ✅ | `full` |
| `encryption_at_rest` | TEXT | ✅ | `AES-256-GCM` |
| `backup_frequency` | TEXT | ✅ | `daily` |
| `plan_tier` | TEXT | ✅ | `ENTERPRISE` |
| `subscription_status` | TEXT | ✅ | `ACTIVE` |
| `admin_email` | TEXT | ✅ | email del administrador |

**CSV esperado:** `bos_tenant.csv`
```csv
tenant_id,nombre,tenant_type,status,verification_status,legal_name,tax_id,country,realm_kc,realm_kc_ext,namespace_k8s,domain,isolation_level,mfa_required,password_policy,session_ttl_max,token_ttl_seconds,audit_level,encryption_at_rest,backup_frequency,plan_tier,subscription_status,admin_email
skull,SKULL Desarrollo de Software,STANDARD,ACTIVE,VERIFIED,SKULL Desarrollo de Software S.R.L.,123456789,BO,skull,skull-ext,sbos-system,skull.sbos.skull.bo,SCHEMA_PER_TENANT,false,"length(12)_argon2id_t3_m64",28800,3600,full,AES-256-GCM,daily,ENTERPRISE,ACTIVE,admin@skull.bo
```

---

## 12. bos_tenant_config — Configuración del Tenant

| Campo | Tipo | Obligatorio | Ejemplo |
|-------|------|------------|--------|
| `tenant_id` | TEXT | ✅ PK + FK→bos_tenant | `skull` |
| `default_language` | CHAR(2) | | `ES` |
| `default_timezone` | TEXT | | `America/La_Paz` |
| `default_currency` | CHAR(3) | | `BOB` |

**CSV esperado:** `bos_tenant_config.csv`
```csv
tenant_id,default_language,default_timezone,default_currency
skull,ES,America/La_Paz,BOB
```

---

## 13. bos_tenant_domain — Dominios del Tenant

| Campo | Tipo | Obligatorio | Ejemplo |
|-------|------|------------|--------|
| `tenant_id` | TEXT | ✅ PK | `skull` |
| `domain_name` | TEXT | ✅ PK | `skull.sbos.skull.bo` |
| `verified` | BOOLEAN | | `true` |
| `ssl_enabled` | BOOLEAN | | `true` |

**CSV esperado:** `bos_tenant_domain.csv`
```csv
tenant_id,domain_name,verified,ssl_enabled
skull,skull.sbos.skull.bo,true,true
```

---

## 14. bos_tenant_network — Rangos CIDR del Tenant

| Campo | Tipo | Obligatorio | Ejemplo |
|-------|------|------------|--------|
| `tenant_id` | TEXT | ✅ PK | `skull` |
| `network_id` | BIGSERIAL | ✅ PK | — |
| `cidr_range` | CIDR | ✅ | `10.0.0.0/8` |
| `description` | TEXT | | `Red Interna SKULL` |
| `deny` | BOOLEAN | | `false` (false=whitelist, true=blacklist) |

**CSV esperado:** `bos_tenant_network.csv`
```csv
tenant_id,cidr_range,description,deny
skull,10.0.0.0/8,Red Interna SKULL,false
skull,172.16.0.0/12,Red de Desarrollo,false
skull,192.168.0.0/16,Red de Oficina,false
skull,200.87.0.0/16,IPs Públicas Bolivia,false
```

---

## 15. bos_tenant_currency — Monedas del Tenant

| Campo | Tipo | Obligatorio | Ejemplo |
|-------|------|------------|--------|
| `tenant_id` | TEXT | ✅ PK | `skull` |
| `currency_code` | CHAR(3) | ✅ PK + FK→bos_moneda | `BOB` |
| `is_default` | BOOLEAN | | `true` |

**CSV esperado:** `bos_tenant_currency.csv`
```csv
tenant_id,currency_code,is_default
skull,BOB,true
skull,USD,false
```

---

## 16. bos_tenant_language — Idiomas del Tenant

| Campo | Tipo | Obligatorio | Ejemplo |
|-------|------|------------|--------|
| `tenant_id` | TEXT | ✅ PK | `skull` |
| `language_code` | CHAR(2) | ✅ PK + FK→bos_idioma | `ES` |
| `is_default` | BOOLEAN | | `true` |

**CSV esperado:** `bos_tenant_language.csv`
```csv
tenant_id,language_code,is_default
skull,ES,true
skull,EN,false
```

---

## 17. bos_empresa — Empresa Inicial

| Campo | Tipo | Obligatorio | Ejemplo |
|-------|------|------------|--------|
| `empresa_id` | TEXT | ✅ PK (UUID) | `aaaaaaaa-0001-0000-0000-000000000001` |
| `tenant_id` | TEXT | ✅ FK→bos_tenant | `skull` |
| `nombre` | TEXT | ✅ | `SKULL Desarrollo de Software S.R.L.` |
| `nit` | TEXT | | NIT Bolivia |
| `activo` | BOOLEAN | | `true` |

---

## 18. bos_sucursal — Sucursal Principal

| Campo | Tipo | Obligatorio | Ejemplo |
|-------|------|------------|--------|
| `sucursal_id` | TEXT | ✅ PK (UUID) | `bbbbbbbb-0001-0000-0000-000000000001` |
| `empresa_id` | TEXT | ✅ FK→bos_empresa | `aaaaaaaa-0001-0000-0000-000000000001` |
| `nombre` | TEXT | ✅ | `Oficina Central` |
| `direccion` | TEXT | | Dirección física |
| `ciudad_id` | BIGINT | FK→bos_ciudad | `1` (La Paz) |
| `activo` | BOOLEAN | | `true` |

---

## 19. bos_pos_logico — POS Inicial

| Campo | Tipo | Obligatorio | Ejemplo |
|-------|------|------------|--------|
| `pos_id` | TEXT | ✅ PK (UUID) | `cccccccc-0001-0000-0000-000000000001` |
| `sucursal_id` | TEXT | ✅ FK→bos_sucursal | `bbbbbbbb-0001-0000-0000-000000000001` |
| `nombre` | TEXT | ✅ | `Administración` |
| `tipo` | TEXT | | `ADMIN` |
| `activo` | BOOLEAN | | `true` |

---

## RESUMEN — 19 tablas para seed data

| # | Tabla | CSV | Prioridad |
|---|-------|-----|----------|
| 1 | `bos_pais` | `bos_pais.csv` | CRÍTICA |
| 2 | `bos_ciudad` | `bos_ciudad.csv` | ALTA |
| 3 | `bos_moneda` | `bos_moneda.csv` | CRÍTICA |
| 4 | `bos_idioma` | `bos_idioma.csv` | ALTA |
| 5 | `bos_timezone` | `bos_timezone.csv` | ALTA |
| 6 | `bos_credential_policy` | `bos_credential_policy.csv` | CRÍTICA |
| 7 | `bos_financial_tipo_transaccion` | `bos_financial_tipo_transaccion.csv` | CRÍTICA |
| 8 | `bos_gestion` | `bos_gestion.csv` | ALTA |
| 9 | `bos_gestion_calendario` | `bos_gestion_calendario.csv` | ALTA |
| 10 | `bos_sod_conflict_matrix` | `bos_sod_conflict_matrix.csv` | CRÍTICA |
| 11 | `bos_tenant` | `bos_tenant.csv` | CRÍTICA |
| 12 | `bos_tenant_config` | `bos_tenant_config.csv` | CRÍTICA |
| 13 | `bos_tenant_domain` | `bos_tenant_domain.csv` | MEDIA |
| 14 | `bos_tenant_network` | `bos_tenant_network.csv` | MEDIA |
| 15 | `bos_tenant_currency` | `bos_tenant_currency.csv` | ALTA |
| 16 | `bos_tenant_language` | `bos_tenant_language.csv` | ALTA |
| 17 | `bos_empresa` | `bos_empresa.csv` | CRÍTICA |
| 18 | `bos_sucursal` | `bos_sucursal.csv` | CRÍTICA |
| 19 | `bos_pos_logico` | `bos_pos_logico.csv` | CRÍTICA |

**Tablas ya pobladas por el DDL unificado (no requieren CSV):**
- `bos_privilege.bos_domain` — 12 dominios ✅
- `bos_privilege.bos_verb` — 4 verbos ✅
- `bos_privilege.bos_application` — 6 aplicaciones ✅

---

*B38-CATALOGO-TABLAS-SEED.md · SKULL · SBOS · Junio 2026*
