# Anexo A.05 — El Catálogo de Átomos de Dominio v2.0
## Documento de respaldo: el modelo de átomo de elemento — cada plano de control es una aplicación

**Tipo:** ANEXO — documento de respaldo del corpus
**Versión del anexo:** 1.0.0 · **Fecha:** 2026-07-11
**Estatus:** FUENTE AUTOSUFICIENTE — contiene el catálogo COMPLETO (traslado fiel, §6)
**Respalda a:** MANUAL-ATOMOS (1.03) §4.5 · MANUAL-DOMINIOS (1.01) §2.1 · MANUAL-VERBOS (1.02) §8 · MANUAL-D00 (1.06) §7.2 · A.01 §17 (los dominios del rol)
**Fuentes de origen (cita histórica):** `BAUTH-CATALOGO-ATOMOS-DOMINIOS-v2` v2.0 (2026-07-10) — estado **DISEÑO, pendiente aprobación DDL (HITL)**
**Normas base:** por dominio — OSDP/IEC 60839/800-116 (D2) · PCI/SOX/ISO 20022 (D3) · GTRBAC/RFC 5545 (D4) · ISO 30107-3 (D5) · OGC GeoFence (D6) · 800-207/802.1X (D7) · SBOS-049/W3C Trace (D8) · 800-63B-4/FIDO2 (D9) · INCITS 359 DSD (D10) · A.8.15/PCI 10.3.2/RGPD (D11) · RFC 6962/NIST IR 8202 (D12) · Ley 164 (D13)

---

## Tabla de contenidos

1. [Propósito y cómo citarlo](#1-propósito-y-cómo-citarlo)
2. [El modelo de átomo de elemento — la corrección v1→v2](#2-el-modelo-de-átomo-de-elemento--la-corrección-v1v2)
3. [El mapa de posiciones y el catálogo por dominio](#3-el-mapa-de-posiciones-y-el-catálogo-por-dominio)
4. [El plan de implementación (HITL pendiente)](#4-el-plan-de-implementación-hitl-pendiente)
5. [Verificación de completitud](#5-verificación-de-completitud)
6. [Traslado fiel — el catálogo completo](#6-traslado-fiel--el-catálogo-completo)
7. [Referencias e historial](#7-referencias-e-historial)

---

## 1. Propósito y cómo citarlo

Respaldo del catálogo de átomos de los planos de control D00–D13 bajo el **modelo de átomo de
elemento** (v2.0). **Cómo citarlo:** `A.05 §D7` (los átomos de red) · `A.05 §2` (el modelo).
**Frontera:** la doctrina del átomo (tipos, BitMask, slots) vive en 1.03/1.04; este anexo
respalda con el catálogo concreto. **Autosuficiencia:** el enforcement de estos átomos es del
PrivilegeEngine nativo (los motores externos fueron eliminados — ADR-010).

---

## 2. El modelo de átomo de elemento — la corrección v1→v2

El catálogo v1 tenía dos errores corregidos por v2:

| Error v1 | Corrección v2 |
|---|---|
| Numeración NO canónica (v1 «D4»=Físico…) | Numeración canónica de `catalog.rs SEED_DOMAINS`: D2=Físico, D3=Financiero… D12=Blockchain, D13=Firma |
| **CRUD por campo** (4 átomos C/R/U/D por cada campo → ~5.808 átomos, mayoría vacíos) | **Átomo de elemento** (1 átomo por elemento semántico → **~72 átomos reales D2–D12**); el ver/editar lo rige la **matriz por tier** (1.06 §8) |

**El modelo:** `D{n}.{dominio-como-app}.{grupo}.{elemento}` — cada plano de control es su
propia aplicación con namespace (`pacs`, `fin`, `cal`, `bio`, `geo`, `net`, `ctx`, `cred`,
`delegate`, `audit`, `blk`, `sign`); el verbo ES el elemento semántico del dominio (no CRUD —
el CRUD solo aplica a D1 Lógico, apps reales, seed generativo `bauth_06`). El átomo declara
que el elemento EXISTE (posición en el BitMask); su VALOR vive en `privilege_role_atom.value`.
**Tipos:** ACCIÓN · REGLA · MÉTODO · IDENTIDAD (1.03 §4).

**Resultado:** el catálogo completo de dominios de control son **~128 átomos semánticos**
(D00:20 + D2–D12:72 + D13:36) — no miles; los miles del sistema son D1 (apps reales).

---

## 3. El mapa de posiciones y el catálogo por dominio

Bloques de 20 posiciones por dominio (propuesto, HITL): D00 `org` 5809–5828 (20, establecido)
· D2 `pacs` 6001+ (7) · D3 `fin` 6021+ (6) · D4 `cal` 6041+ (6) · D5 `bio` 6061+ (4) · D6
`geo` 6081+ (4) · D7 `net` 6101+ (10) · D8 `ctx` 6121+ (5) · D9 `cred` 6141+ (14) · D10
`delegate` 6161+ (3) · D11 `audit` 6181+ (7) · D12 `blk` 6201+ (6) · **D13 `sign` 5929–5964
(36, establecido — ya era modelo de elemento)**. Reservas: 5829–5928 y 5965–6000.

El catálogo completo — átomo por átomo con tipo, valor/validación, tier de acceso y posición —
está íntegro en §6. Piezas notables: `D9.cred.politica.password_rotation` con `0 = sin
rotación forzada` (NIST 800-63B-4) · los átomos RGPD de D11 (consentimiento Art. 7,
portabilidad Art. 20, olvido Art. 17) · el anclaje D12 con variantes A(Merkle)/B(liquidación).

---

## 4. El plan de implementación (HITL pendiente)

Los 7 pasos del artefacto: aprobar el catálogo → registrar las 11 apps de dominio en
`privilege_application` → los grupos en `privilege_group` → los verbos semánticos en
`privilege_verb` → generar el seed idempotente de los 72 átomos (sin tocar D00/D13) → deprecar
v1 → poblar defaults por tier en `privilege_role_atom.value`. **Prerequisito:** columna
`atom_type` en `privilege_atom` (plan de migración atómica — 1.03 §2.2).

---

## 5. Verificación de completitud

| Verificación | Resultado |
|---|---|
| 13/13 planos con átomos (D00–D13; D1 por seed generativo aparte) | ✅ |
| Coherencia con la numeración canónica (`catalog.rs`) | ✅ — es la corrección central de v2 |
| Coherencia con el `bit_slot` inmutable | ✅ — v2 propone posiciones NUEVAS (6001+); no reasigna slots usados (regla absoluta) |
| Estado honesto | **DISEÑO — pendiente aprobación DDL (HITL)**: los 72 átomos D2–D12 no están sembrados; D00 (20) y D13 (36) sí están establecidos |
| Alineación con A.01 §17 | ✅ — los átomos de D6/D7/D8/D9/D12 materializan los bloques B15–B19 del rol |

---

## 6. Traslado fiel — el catálogo completo

### BAUTH — Catálogo de Átomos de Dominio v2.0 (Modelo de Elemento)
#### Cada plano de control es una aplicación · verbos semánticos, NO CRUD

**Versión:** 2.0.0 · **Fecha:** 2026-07-10 · **Autor:** bauth-developer  
**Estado:** DISEÑO — pendiente aprobación DDL (HITL, schema `bauth`)  
**Supersede:** `BAUTH-CATALOGO-ATOMOS-D4-D12.md` v1 (numeración no canónica + CRUD-por-campo)  
**Referencia de modelo:** MANUAL-ATOMOS §4.5 · MANUAL-DOMINIOS §2.1 · MANUAL-D00 §7.2

---

#### 0. Qué cambia respecto de v1 — y por qué

El catálogo v1 tenía **dos errores** que este rediseño corrige:

| Error de v1 | Corrección v2 |
|-------------|---------------|
| **Numeración no canónica** (v1 «D4»=Físico, «D7»=Financiero, «D8»=Temporal, «D12»=Delegación+GDPR) | **Numeración canónica** `catalog.rs SEED_DOMAINS`: D2=Físico, D3=Financiero, D4=Temporal … D12=Blockchain, D13=Firma |
| **CRUD por campo** (`D4.pacs.zone_access.C/R/U/D` = 4 átomos/campo) | **Átomo de elemento** (`D2.pacs.zone_access` = 1 átomo); el ver/editar es la matriz por tier |
| **484 slots reservados por dominio** (~5.808 átomos, mayoría vacíos) | **~72 átomos de elemento reales** para D2–D12 (los que existen) |

**El principio (MANUAL-ATOMOS §4.5):** cada plano de control D2–D13 es **su propia aplicación**
con namespace propio (`pacs`, `fin`, `cal`, `bio`, `geo`, `net`, `ctx`, `cred`, `delegate`,
`audit`, `blk`, `sign`), y sus verbos son los **elementos semánticos** del dominio, no C/R/U/D.
El CRUD como verbo solo aplica a **D1 Lógico** (acceso a apps reales, donde `create`≠`read` sobre
un registro — esos átomos viven en el seed generativo `bauth_06`, no en este catálogo).

**Reducción:** de ~5.808 átomos (v1, CRUD + slots vacíos) a **~72 átomos de elemento** para
D2–D12. Sumados D00 (20) y D13 (36): el catálogo de dominios de control completo son **~128
átomos semánticos**, no miles. Los miles de átomos del sistema son los de D1 Lógico (apps reales).

---

#### 1. El modelo de átomo de elemento

```
Átomo de elemento = D{n}.{dominio-como-app}.{grupo}.{elemento_semántico}
                     │        │                 │        └── el verbo ES el elemento (nit, max_daily…)
                     │        │                 └── sub-área del dominio
                     │        └── el dominio es la aplicación (pacs, fin, cal…)
                     └── plano de control (canónico)

  · El átomo declara que el elemento EXISTE (una posición en el BitMask).
  · Su VALOR vive en privilege_role_atom.value (REGLA) o es binario (ACCIÓN/IDENTIDAD).
  · Quién puede VER/EDITAR el elemento = la matriz por tier/rol (no átomos C/R/U/D por campo).
```

**Tipos de átomo** (el tipo lo da la naturaleza del elemento — MANUAL-ATOMOS §4):
`ACCIÓN` (operación: door_unlock, invoice_emit) · `REGLA` (parámetro con valor: max_daily,
match_threshold) · `MÉTODO` (procedimiento: password, totp) · `IDENTIDAD` (propiedad del sujeto).

---

#### 2. Mapa de posiciones (propuesto — HITL)

Bloques de 20 posiciones por dominio (holgura para crecer). D00 y D13 conservan las suyas.

| Dominio | App | Rango propuesto | Átomos reales |
|---------|-----|-----------------|:-------------:|
| D00 Identidad | `org` | 5809–5828 (establecido) | 20 |
| D2 Físico | `pacs` | 6001–6020 | 7 |
| D3 Financiero | `fin` | 6021–6040 | 6 |
| D4 Temporal | `cal` | 6041–6060 | 6 |
| D5 Biométrico | `bio` | 6061–6080 | 4 |
| D6 Geoespacial | `geo` | 6081–6100 | 4 |
| D7 Red | `net` | 6101–6120 | 10 |
| D8 Contexto | `ctx` | 6121–6140 | 5 |
| D9 Credenciales | `cred` | 6141–6160 | 14 |
| D10 Delegación | `delegate` | 6161–6180 | 3 |
| D11 Auditoría | `audit` | 6181–6200 | 7 |
| D12 Blockchain | `blk` | 6201–6220 | 6 |
| D13 Firma | `sign` | 5929–5964 (establecido) | 36 |

*D1 Lógico usa apps reales (tryton, superset…) y el seed generativo `bauth_06` — fuera de este
catálogo. Reservas libres: 5829–5928 (100) y 5965–6000 (36).*

---

#### 3. Catálogo por dominio

> **Nota de acceso (una vez para todo el catálogo):** el ver/editar de cada elemento se rige por
> la **matriz por tier** (MANUAL-D00 §8) — no hay átomos CRUD por campo. La columna «Acceso»
> indica el tier mínimo que puede *modificar* el elemento (leer suele ser un tier menor).

##### D2 — Físico · app `pacs` (Physical Access Control System)

Estándares: ANSI/SIA AC-01 · OSDP 2.2 · IEC 60839-11 · NIST SP 800-116 Rev.1 · ISO 22341:2021

| Átomo | Tipo | Valor / Validación | Acceso | pos |
|-------|:----:|--------------------|:------:|:---:|
| `D2.pacs.acceso.zone_access` | REGLA | lista de zonas físicas permitidas | BIZ_N3 | 6001 |
| `D2.pacs.acceso.door_unlock` | ACCIÓN | puede abrir puertas de su zona | BIZ_N4 | 6002 |
| `D2.pacs.acceso.floor_access` | REGLA | pisos accesibles (lista) | BIZ_N3 | 6003 |
| `D2.pacs.acceso.schedule_override` | ACCIÓN | excepción de horario físico | BIZ_N3 | 6004 |
| `D2.pacs.acceso.visitor_escort` | REGLA | puede escoltar visitantes (bool) | BIZ_N4 | 6005 |
| `D2.pacs.acceso.anti_passback_exempt` | REGLA | exención anti-passback (bool) | BIZ_N2 | 6006 |
| `D2.pacs.acceso.camera_view` | ACCIÓN | acceso a cámaras/CCTV (ONVIF) | BIZ_N4 | 6007 |

##### D3 — Financiero · app `fin`

Estándares: PCI DSS 4.0.1 · SOX §404 · COSO · ISO 20022

| Átomo | Tipo | Valor / Validación | Acceso | pos |
|-------|:----:|--------------------|:------:|:---:|
| `D3.fin.limites.amount_max_daily` | REGLA | monto máximo diario (moneda del tenant) | BIZ_N2 | 6021 |
| `D3.fin.limites.amount_max_single` | REGLA | monto máximo por transacción | BIZ_N2 | 6022 |
| `D3.fin.limites.cashout_limit` | REGLA | límite de retiro de efectivo | BIZ_N2 | 6023 |
| `D3.fin.control.approval_required` | REGLA | umbral que exige dual-approval (SoD) | BIZ_N1 | 6024 |
| `D3.fin.control.currency_allowed` | REGLA | monedas permitidas (ISO 4217, lista) | BIZ_N2 | 6025 |
| `D3.fin.ops.invoice_emit` | ACCIÓN | puede emitir factura (SFV/SIN) | BIZ_N3 | 6026 |

##### D4 — Temporal · app `cal`

Estándares: GTRBAC · RFC 5545 · ISO 8601

| Átomo | Tipo | Valor / Validación | Acceso | pos |
|-------|:----:|--------------------|:------:|:---:|
| `D4.cal.horario.schedule_days` | REGLA | días permitidos (L-D, lista) | BIZ_N3 | 6041 |
| `D4.cal.horario.schedule_hours` | REGLA | franja horaria (HH:MM-HH:MM) | BIZ_N3 | 6042 |
| `D4.cal.horario.holiday_access` | REGLA | acceso en feriados (bool) | BIZ_N2 | 6043 |
| `D4.cal.sesion.session_max_duration` | REGLA | duración máx. de sesión (segundos) | BIZ_N2 | 6044 |
| `D4.cal.vigencia.valid_from` | REGLA | inicio de vigencia (fecha) | BIZ_N2 | 6045 |
| `D4.cal.vigencia.valid_until` | REGLA | fin de vigencia (fecha) | BIZ_N2 | 6046 |

##### D5 — Biométrico · app `bio`

Estándares: ISO/IEC 30107-3 (PAD) · NIST SP 800-63B-4 §5.2.3

| Átomo | Tipo | Valor / Validación | Acceso | pos |
|-------|:----:|--------------------|:------:|:---:|
| `D5.bio.politica.biometric_required` | REGLA | exige biometría (bool) | BIZ_N2 | 6061 |
| `D5.bio.politica.biometric_type` | REGLA | ENUM: `huella`/`rostro`/`iris`/`voz`/`palma` | BIZ_N2 | 6062 |
| `D5.bio.politica.liveness_required` | REGLA | anti-spoofing PAD (bool) | BIZ_N2 | 6063 |
| `D5.bio.politica.match_threshold` | REGLA | umbral de coincidencia (float 0-1) | BIZ_N1 | 6064 |

##### D6 — Geoespacial · app `geo`

Estándares: OGC GeoFence · BeyondCorp

| Átomo | Tipo | Valor / Validación | Acceso | pos |
|-------|:----:|--------------------|:------:|:---:|
| `D6.geo.cerca.geofence_zone` | REGLA | geocercas permitidas (polígonos) | BIZ_N3 | 6081 |
| `D6.geo.cerca.country_restrict` | REGLA | países permitidos (ISO 3166, lista) | BIZ_N2 | 6082 |
| `D6.geo.ubicacion.location_precision` | REGLA | precisión GPS mínima (metros) | BIZ_N3 | 6083 |
| `D6.geo.ubicacion.location_required` | REGLA | exige ubicación (bool) | BIZ_N2 | 6084 |

##### D7 — Red · app `net` (grupos: `network`, `device`)

Estándares: NIST SP 800-207 ZTA · IEEE 802.1X · device posture

| Átomo | Tipo | Valor / Validación | Acceso | pos |
|-------|:----:|--------------------|:------:|:---:|
| `D7.net.network.ip_whitelist` | REGLA | CIDRs permitidos (lista) | BIZ_N2 | 6101 |
| `D7.net.network.country_ip_allow` | REGLA | países de IP permitidos | BIZ_N2 | 6102 |
| `D7.net.network.vpn_required` | REGLA | exige VPN (bool) | BIZ_N2 | 6103 |
| `D7.net.network.mtls_required` | REGLA | exige mTLS (bool) | BIZ_N1 | 6104 |
| `D7.net.network.tls_min_version` | REGLA | ENUM: `1.2`/`1.3` | BIZ_N1 | 6105 |
| `D7.net.device.device_register` | ACCIÓN | registrar dispositivo | BIZ_N4 | 6106 |
| `D7.net.device.device_policy` | REGLA | política MDM aplicable | BIZ_N2 | 6107 |
| `D7.net.device.device_trust_level` | REGLA | nivel de confianza mínimo | BIZ_N2 | 6108 |
| `D7.net.device.device_remote_wipe` | ACCIÓN | borrado remoto del dispositivo | BIZ_N1 | 6109 |
| `D7.net.device.jailbreak_block` | REGLA | bloquear dispositivos rooteados (bool) | BIZ_N2 | 6110 |

##### D8 — Contexto · app `ctx`

Estándares: SBOS-049 · NIST SP 800-207 · W3C Trace Context

| Átomo | Tipo | Valor / Validación | Acceso | pos |
|-------|:----:|--------------------|:------:|:---:|
| `D8.ctx.sesion.max_concurrent_sessions` | REGLA | sesiones simultáneas máx. | BIZ_N2 | 6121 |
| `D8.ctx.sesion.session_ttl` | REGLA | TTL de sesión (segundos) | BIZ_N2 | 6122 |
| `D8.ctx.sesion.inactivity_timeout` | REGLA | timeout por inactividad (segundos) | BIZ_N3 | 6123 |
| `D8.ctx.sesion.context_switch_allowed` | REGLA | puede cambiar de contexto (bool) | BIZ_N2 | 6124 |
| `D8.ctx.riesgo.risk_threshold_stepup` | REGLA | score que dispara step-up (0-1) | BIZ_N1 | 6125 |

##### D9 — Credenciales · app `cred` (grupos: `metodo`, `politica`)

Estándares: NIST SP 800-63B-4 AAL1-3 · FIDO2/WebAuthn · RFC 6238/4226/8705

**Métodos** (tipo MÉTODO — disponible/requerido/alternativa por contexto):

| Átomo | Tipo | Valor | Acceso | pos |
|-------|:----:|-------|:------:|:---:|
| `D9.cred.metodo.password` | MÉTODO | AAL1 · Argon2id | BIZ_N3 | 6141 |
| `D9.cred.metodo.totp` | MÉTODO | AAL2 · RFC 6238 | BIZ_N3 | 6142 |
| `D9.cred.metodo.hotp` | MÉTODO | AAL2 · RFC 4226 | BIZ_N3 | 6143 |
| `D9.cred.metodo.webauthn` | MÉTODO | AAL2-3 · W3C L3 | BIZ_N3 | 6144 |
| `D9.cred.metodo.mtls` | MÉTODO | AAL3 · RFC 8705 | BIZ_N1 | 6145 |
| `D9.cred.metodo.email_otp` | MÉTODO | AAL1 restringido | BIZ_N3 | 6146 |
| `D9.cred.metodo.push` | MÉTODO | AAL2 · Ed25519 | BIZ_N3 | 6147 |
| `D9.cred.metodo.recovery` | MÉTODO | AAL1 · códigos únicos | BIZ_N3 | 6148 |
| `D9.cred.metodo.saml` | MÉTODO | AAL1-2 · SAML 2.0 | BIZ_N2 | 6149 |

**Política de credenciales** (tipo REGLA):

| Átomo | Tipo | Valor / Validación | Acceso | pos |
|-------|:----:|--------------------|:------:|:---:|
| `D9.cred.politica.min_length` | REGLA | longitud mínima de contraseña | BIZ_N2 | 6150 |
| `D9.cred.politica.hibp_enabled` | REGLA | screening HIBP (bool) | BIZ_N2 | 6151 |
| `D9.cred.politica.mfa_required` | REGLA | exige MFA (bool) | BIZ_N1 | 6152 |
| `D9.cred.politica.aal_min` | REGLA | AAL mínimo (1-3) | BIZ_N1 | 6153 |
| `D9.cred.politica.password_rotation` | REGLA | rotación (días; 0=sin rotación forzada, NIST) | BIZ_N2 | 6154 |

##### D10 — Delegación · app `delegate`

Estándares: ANSI/INCITS 359 DSD · NIST AC-5

| Átomo | Tipo | Valor / Validación | Acceso | pos |
|-------|:----:|--------------------|:------:|:---:|
| `D10.delegate.control.delegate_permission` | REGLA | puede delegar (bool) — reducción AND | BIZ_N2 | 6161 |
| `D10.delegate.control.delegate_max_depth` | REGLA | profundidad máx. de delegación | BIZ_N1 | 6162 |
| `D10.delegate.control.delegate_max_duration` | REGLA | duración máx. (días) | BIZ_N2 | 6163 |

##### D11 — Auditoría · app `audit` (grupos: `registro`, `compliance`)

Estándares: ISO 27001 A.8.15 · PCI DSS 10.3.2 · NIST AU-2/3 · RGPD Arts. 15/17/20

| Átomo | Tipo | Valor / Validación | Acceso | pos |
|-------|:----:|--------------------|:------:|:---:|
| `D11.audit.registro.audit_view_own` | ACCIÓN | ver la auditoría propia | BIZ_N4 | 6181 |
| `D11.audit.registro.audit_view_tenant` | ACCIÓN | ver la auditoría del tenant | BIZ_N2 | 6182 |
| `D11.audit.registro.audit_export` | ACCIÓN | exportar registros de auditoría | BIZ_N2 | 6183 |
| `D11.audit.compliance.consent_manage` | ACCIÓN | gestionar consentimientos (RGPD Art.7) | BIZ_N2 | 6184 |
| `D11.audit.compliance.data_portability` | ACCIÓN | portabilidad de datos (RGPD Art.20) | BIZ_N2 | 6185 |
| `D11.audit.compliance.right_to_forget` | ACCIÓN | derecho al olvido (RGPD Art.17) | BIZ_N1 | 6186 |
| `D11.audit.compliance.data_retention_override` | REGLA | override de retención (días) | BIZ_N1 | 6187 |

##### D12 — Blockchain · app `blk`

Estándares: RFC 6962 (Merkle) · NIST IR 8202 · QBFT · Ley 164 (anclaje D12↔D13)

| Átomo | Tipo | Valor / Validación | Acceso | pos |
|-------|:----:|--------------------|:------:|:---:|
| `D12.blk.anclaje.anchor_enabled` | REGLA | anclaje de auditoría activo (bool) | BIZ_N1 | 6201 |
| `D12.blk.anclaje.anchor_variant` | REGLA | ENUM: `A`(Merkle) / `B`(liquidación Besu) | SU | 6202 |
| `D12.blk.anclaje.anchor_frequency` | REGLA | frecuencia de anclaje (min o N eventos) | BIZ_N1 | 6203 |
| `D12.blk.anclaje.merkle_batch_size` | REGLA | tamaño de lote Merkle (máx. 1M) | BIZ_N1 | 6204 |
| `D12.blk.liquidacion.settlement_enabled` | REGLA | liquidación on-chain (bool, Forma B) | SU | 6205 |
| `D12.blk.liquidacion.reconcile_interval` | REGLA | intervalo de reconciliación (min) | BIZ_N1 | 6206 |

##### D13 — Firma Digital Externa · app `sign`

**Sin cambios** — el diseño D13 (`BAUTH-DOMINIO-D13-BLOCKCHAIN.md`) **ya usa el modelo de
elemento** (no CRUD): 36 átomos en 3 grupos `chain`/`did`/`legalsg`, posiciones 5929–5964,
todos `blockchain_anchored=1`, `legalsg` con `min_trust=Critical`. Se referencia aquí como
parte del catálogo canónico, sin modificar.

---

#### 4. Comparativa v1 → v2

| Métrica | v1 (CRUD) | v2 (elemento) |
|---------|:---------:|:-------------:|
| Numeración | no canónica (D4=Físico…) | canónica (D2=Físico…) |
| Átomos por elemento | 4 (C/R/U/D) | 1 |
| Átomos D2–D12 | ~5.808 (con slots vacíos) | **72** |
| Catálogo de dominios de control completo | miles | **~128** (D00:20 + D2-D12:72 + D13:36) |
| Cómo se controla ver/editar | átomos CRUD por campo | matriz por tier (D00 §8) |
| App por dominio | mezcla (algunos «bauth») | dedicada (pacs, fin, cal, bio…) |

---

#### 5. Implementación (HITL — schema `bauth`)

1. **Aprobar** este catálogo v2 (taxonomía de apps + elementos + posiciones).
2. **Registrar las 11 apps de dominio** en `privilege_application` (pacs, fin, cal, bio, geo,
   net, ctx, cred, delegate, audit, blk) — con sus `app_code` (rango 14+, tras org=13).
3. **Registrar los grupos** de cada app en `privilege_group`.
4. **Registrar los verbos semánticos** en `privilege_verb` (los elementos: zone_access,
   amount_max_daily, etc.) — continúan la secuencia tras los verbos 51-63 de D00.
5. **Generar el seed** `bauth_NN__atoms_dominios_v2.sql` con los 72 átomos + sus posiciones,
   idempotente (`ON CONFLICT`, sin TRUNCATE que borre D00/D13).
6. **Deprecar** `BAUTH-CATALOGO-ATOMOS-D4-D12.md` v1.
7. **Poblar valores** por rol en `privilege_role_atom.value` (los defaults de política por tier).

**Prerequisito:** la columna `atom_type` en `privilege_atom` (Fase 1 del plan de migración
atómica — MANUAL-ATOMOS §2.2) para distinguir ACCIÓN/REGLA/MÉTODO/IDENTIDAD.

---

#### 6. Trazabilidad

| Documento | Relación |
|-----------|----------|
| `BAUTH-CATALOGO-ATOMOS-D4-D12.md` v1 | **Superado por este** |
| `BAUTH-CATALOGO-ATOMOS-D00-CRUD.md` | Descartado (mismo error CRUD) — ver MANUAL-D00 §7.2 |
| `BAUTH-DOMINIO-D13-BLOCKCHAIN.md` | Vigente — D13 ya es modelo de elemento |
| MANUAL-ATOMOS §4.5 · MANUAL-DOMINIOS §2.1 · MANUAL-D00 §7.2 · MANUAL-VERBOS §8 | El modelo formalizado |
| `catalog.rs` SEED_DOMAINS | Numeración canónica de dominios (fuente de verdad) |


---

## 7. Referencias e historial

**Del proyecto:** `BAUTH-CATALOGO-ATOMOS-DOMINIOS-v2` (origen) · 1.03 · 1.01 · 1.02 · 1.06 · `catalog.rs SEED_DOMAINS`.

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-11 | Anexo inicial: el modelo de átomo de elemento (corrección v1→v2: numeración canónica + fin del CRUD-por-campo — de ~5.808 a ~128 átomos semánticos), mapa de posiciones por dominio-como-app, catálogo íntegro por traslado fiel, plan de implementación HITL y verificación (slots inmutables respetados; estado DISEÑO honesto). |
