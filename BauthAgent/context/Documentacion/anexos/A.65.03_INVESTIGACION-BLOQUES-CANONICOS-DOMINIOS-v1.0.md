# A.65.03 — Investigación Normativa: Bloques Canónicos por Dominio
## Catálogo completo D00–D15 · D98 · D99 — estándares, bloques, átomos y gaps

**Versión:** 1.6.0
**Fecha:** 2026-07-23
**Tipo:** Investigación + referencia normativa
**Serie:** A.65 · DDL y arquitectura atómica de bAuth
**Autor:** bAuth Identity Core — SBOS (investigación asistida + validación normativa externa)

**Fuentes primarias:** NIST SP 800-63-4 (ago 2025) · NIST SP 800-53 Rev. 5.2 (ago 2025) ·
IEC 60839-11-5:2020 · SIA OSDP v2.2.2 (oct 2024) · PCI DSS 4.0.1 (2024) · ISO/IEC 30107-3 ·
NIST SP 800-207 + 207A · OpenID CAEP 1.0 Final (2025) · INCITS 359-2012 R2022 ·
ISO 27001:2022 A.8.15 · NIST IR 8202 · W3C DID Core v1.1 · RFC 3161 · ETSI EN 319 422 ·
SPIFFE/SPIRE (CNCF) · GTRBAC (Bertino et al.) · Ley 164 Bolivia · DS 5519/AGETIC

---

## Tabla de contenidos

1. [Metodología y alcance](#1-metodología-y-alcance)
2. [D00 — Identidad Organizacional](#2-d00--identidad-organizacional)
3. [D01 — Acceso Lógico](#3-d01--acceso-lógico)
4. [D02 — Acceso Físico](#4-d02--acceso-físico)
5. [D03 — Financiero](#5-d03--financiero)
6. [D04 — Temporal](#6-d04--temporal)
7. [D05 — Biométrico](#7-d05--biométrico)
8. [D06 — Geoespacial](#8-d06--geoespacial)
9. [D07 — Red](#9-d07--red)
10. [D08 — Contexto / Sesión](#10-d08--contexto--sesión)
11. [D09 — Credenciales](#11-d09--credenciales)
12. [D10 — Delegación](#12-d10--delegación)
13. [D11 — Auditoría](#13-d11--auditoría)
14. [D12 — Blockchain / Anclaje](#14-d12--blockchain--anclaje)
15. [D13 — Firma Digital Externa](#15-d13--firma-digital-externa)
16. [D14 — Acceso Privilegiado (PAM)](#16-d14--acceso-privilegiado-pam)
17. [D15 — Identidad No Humana (NHI)](#17-d15--identidad-no-humana-nhi)
18. [D98 — Registro Estructural](#18-d98--registro-estructural)
19. [D99 — Administrativo Global](#19-d99--administrativo-global)
20. [Matriz de completitud normativa](#20-matriz-de-completitud-normativa)
21. [Gaps críticos y recomendaciones](#21-gaps-críticos-y-recomendaciones)
22. [Tabla del RolTemplate — Bloques canónicos consolidados](#22-tabla-del-roltemplate--bloques-canónicos-consolidados-por-dominio)

---

## 1. Metodología y alcance

### 1.1 Objetivo

Este anexo sistematiza la investigación normativa realizada sobre cada uno de los 18 dominios
de bAuth (D00–D15 + D98 + D99), identificando:

1. Los **bloques canónicos** que cada dominio DEBE tener según las normas vigentes.
2. El **estado actual** en `rol_template_datos.dart` e `idn_roles_template` (BD).
3. Los **gaps** — bloques faltantes, bloques mal nombrados, o normas no cumplidas.
4. **Átomos de referencia** en formato `dNN.bloque.verbo`.

### 1.2 Convenciones

| Símbolo | Significado |
|---------|-------------|
| ✅ | Bloque presente y conforme con la norma |
| ⚠️ | Bloque presente pero incompleto o mal alineado |
| ❌ | Bloque faltante — gap confirmado |
| 🔬 | Categoría emergente — sin norma ISO/NIST formal aún |
| `[N]` | Norma verificada (ISO/NIST/RFC) |
| `[I]` | Patrón de industria (buenas prácticas, sin número de norma) |

### 1.3 Tipo de norma — jerarquía de peso normativo

```
ISO/IEC > NIST SP > RFC/IEEE/ANSI > ETSI/W3C > Patrón de industria > Emergente/IA
```

Un bloque respaldado por `[N]` es exigible en auditoría; uno `[I]` es buena práctica.
Un bloque `🔬` debe documentarse explícitamente como emergente, nunca atribuirle
un número de norma que no existe.

---

## 2. D00 — Identidad Organizacional

**Propósito:** define QUÉ ES la entidad y QUÉ PUEDE LEERSE o ESCRIBIRSE de sus atributos.
Es la "primera parte de identity" del sistema: el árbol organizacional (tenant → bdomain →
bsubdomain → pos → actor) y el catálogo de atributos que lo describe. Pre-condición
estructural de todos los demás dominios — los 478 roles lo requieren como base.

**Pipeline:** Pre-condición estructural — **NO genera bit propio en el BitMask 64-bit.**
Sus átomos son evaluados por el **Motor de Identidad (manual 2.15)**, no por el BitMask.

```
┌──────────────────────────────────────────────────────────────┐
│  D00 · árbol org + atributos  →  Motor de Identidad (2.15)  │  ← PRE-CONDICIÓN
│                                   (sin bits, sin Fast-Path)  │
├──────────────────────────────────────────────────────────────┤
│  D08/D09  Pre-BitMask  (ctx_id vivo, LoA suficiente)         │
├──────────────────────────────────────────────────────────────┤
│  D01/D02  Fast-Path    (bit directo, <0.5 ns)                │
├──────────────────────────────────────────────────────────────┤
│  D03..D07  Policy-Path / External-Path                       │
└──────────────────────────────────────────────────────────────┘
```

**Estándar principal:** ISO/IEC 24760-2:2025 · NIST SP 800-63A-4 (IAL, final agosto 2025) ·
SCIM 2.0 RFC 7643 (Core §4.1 + Enterprise §4.3)

**Fuente de diseño canónica (A.01 + A.02 — leer ANTES de codificar):**
- **A.01 §17.3-D0:** enriquecimiento de B01 `metadata` del RolTemplate con `org_unit_id`,
  `tenant_id`, `sector_code` (CAEB SIN 21 sectores), `accountability_chain`, `data_owner_roles`
  — ISO 24760-2 §5. Sin bloque nuevo en el RolTemplate; D00 vive en B01.
- **A.02 B01:** identidad canónica del UserTemplate (uuid, username, tenant_id, account_type)
  + sección `identity_proofing` (A.02 §19.2-U1: IAL1/2/3, proofing_type, evidence[]).
- **A.02 B03:** posición profesional SCIM Enterprise (department, company, manager,
  employeeNumber, reporting_line) — la posición del actor en la estructura orgánica.
- **A.01 §22:** 20 átomos D00 sembrados en `bauth_50__d00_identidad_seeds.sql` — controlan
  quién puede leer/escribir qué atributo de qué entidad. Patrón legacy de seeds:
  `org.gNN.d00.<atributo>` (ej: `org.g02.d00.nit`, `org.g05.d00.email`).

### 2.1 Bloques canónicos

D00 opera en **cuatro cuadrantes** (A.64 §6 — principio rector General/Particular, aplicado
por separado a Rol y a Usuario):

```
              GENERAL (el molde — aplica a todos)   PARTICULAR (valores de uno específico)
  ──────────┬──────────────────────────────────────┬────────────────────────────────────────
  ROL       │  rol_esquema                         │  rol_entidad
  ──────────┼──────────────────────────────────────┼────────────────────────────────────────
  USUARIO   │  usuario_esquema                     │  usuario_entidad
  ──────────┴──────────────────────────────────────┴────────────────────────────────────────
            + atributos · proofing · consentimiento  (transversales — siempre PARTICULAR)
```

| Capa | Sujeto | Bloque | Descripción | Norma | Fuente en bAuth | Estado |
|------|--------|--------|-------------|-------|-----------------|--------|
| GENERAL | ROL | `rol_esquema` | La estructura canónica que TODOS los roles de identidad deben cumplir: `id`, `parent_id`, `type_id`, `hierarchy_level`, `name{}`, `metadata{}`, `audit{}`, `digital_signature{}`. El MOLDE del RolTemplate — define los campos, no los valores de ningún rol concreto | ISO 24760-2:2025 §5 · SCIM RFC 7643 §4.1 | A.01 B01 §3 (contrato v6.0) · A.64 §6 "Parte A — Identidad general (D00/B01)" | ✅ |
| PARTICULAR | ROL | `rol_entidad` | Los valores concretos de UN rol específico en el árbol: `org_unit_id`, `sector_code`, `tenant_id`, `accountability_chain`, vigencia, aprobadores de cambio. Son los datos que distinguen a VENDEDOR_SENIOR de GERENTE_REGIONAL | ISO 24760-2:2025 §6 · SCIM RFC 7643 §4.3 (Enterprise) | `idn_role_template` ↔ `idn_identidad_entidad` · A.64 §6 "Panel 1 — identidad particular del rol" | ✅ |
| GENERAL | USUARIO | `usuario_esquema` | La estructura canónica que TODOS los usuarios deben cumplir: `uuid`, `username`, `tenant_id`, `account_type`, `version`, `status`, `digital_signature`, campos SCIM Core B01, campos Enterprise B03 (department, company, manager, employeeNumber). El MOLDE del UserTemplate | ISO 24760-2:2025 §5 · SCIM RFC 7643 §4.1+4.3 | A.02 B01+B03 §3–§5 (contrato v6.0) | ✅ |
| PARTICULAR | USUARIO | `usuario_entidad` | Los valores concretos de UN usuario específico: su uuid, su username, su department, su manager, su reporting_line, sus metadatos de posición. Son los datos que distinguen a Juan Pérez de María López | ISO 24760-2:2025 §6 · SCIM RFC 7643 §4.3 (Enterprise) | `idn_user_template` ↔ `idn_identidad_entidad` · A.02 B01+B03 valores por instancia | ✅ |
| PARTICULAR | ROL+USUARIO | `atributos` | Atributos extendidos de UNA entidad específica (`idn_identidad_atributo`): ¿quién puede leer/escribir qué atributo de qué entidad? Motor de Identidad (2.15) evalúa. Los 20 átomos D00 de seeds cubren este bloque — patrón `org.gNN.d00.<attr>` | NIST SP 800-162 §4 · ISO 24760-2:2025 §6.3 | A.01 §22 — `bauth_50__d00_identidad_seeds.sql` | ✅ |
| PARTICULAR | USUARIO | `proofing` | El nivel IAL (1/2/3) alcanzado por UN usuario específico: tipo (auto/remoto/presencial), evidencia FAIR+STRONG+SUPERIOR, fecha, re-proofing programado. Log WORM por evento. Aplica a personas, no a roles | NIST SP 800-63A-4 §4–6 (final agosto 2025) · ISO/IEC 29115:2013 | A.02 §19.2-U1 — `identity_proofing` en B01 del UserTemplate (especificada; pendiente DDL) | ✅ diseño |
| PARTICULAR | USUARIO | `consentimiento` | El consentimiento de UN usuario específico para procesamiento de SUS atributos: versión de política, fecha, canal, derecho de supresión. Obligatorio en IAL2+. Aplica a personas, no a roles | GDPR Art. 6–7 · ISO/IEC 29101:2018 · NIST SP 800-63-4 §10 | Sin bloque en A.01 ni A.02 todavía | ❌ FALTANTE |
| AMBOS | USUARIO | `verifiable_credential` | Emisión y verificación de Verifiable Credentials sobre atributos del sujeto. W3C VCDM 2.0 es W3C Recommendation desde mayo 2025. eIDAS 2.0 lo adopta para EUDI Wallet. SP 800-63-4 §10 incorpora wallets controladas por el sujeto (mDL, VC) | W3C VCDM 2.0 (mayo 2025) · eIDAS 2.0 Art. 45 · SP 800-63-4 §10 | Sin diseño — roadmap SSI | ❌ FALTANTE |
| GENERAL | AMBOS | `fal` | Federation Assurance Level — SP 800-63-4 lo introduce como 3ª dimensión independiente (FAL1/2/3). bAuth actúa como IdP OIDC/SAML y debe declarar el nivel de confianza de sus aserciones de federación | NIST SP 800-63-4 §5 · OpenID Connect Core §3.3 | Sin diseño | ❌ FALTANTE |

### 2.2 Novedades SP 800-63-4 (agosto 2025) relevantes para D00

- El modelo IAL/AAL/FAL se vuelve **modular por función** — cada servicio elige el nivel
  de assurance de forma independiente (no como combo fijo). Impacta el bloque `proofing`.
- Se introduce **Federation Assurance Level (FAL)** como tercera dimensión explícita
  (aserciones SAML/OIDC cuando bAuth actúa como IdP hacia terceros).
- **Wallets controladas por el sujeto** (mDL, Verifiable Credentials W3C) integradas al
  modelo de identidad — roadmap SSI de SBOS directamente aplicable.
- **Consentimiento de privacidad** pasa a ser requerimiento explícito en IAL2+ — refuerza
  el gap del bloque `consentimiento`.

### 2.3 Átomos de referencia

Los átomos D00 siguen el patrón canónico `d00.{bloque}.{verbo}`.
Los cuatro cuadrantes se reflejan directamente en el nombre del bloque:
`rol_esquema` / `rol_entidad` para el ROL y `usuario_esquema` / `usuario_entidad` para el USUARIO.
Los bloques `atributos`, `proofing` y `consentimiento` son siempre PARTICULAR — aplican
solo a instancias concretas.
Patrón legacy de seeds para `atributos`: `org.gNN.d00.<attr>`
(`g02` = datos legales/empresa, `g05` = preferencias del sujeto).

```
═══ ROL — CAPA GENERAL (el molde del RolTemplate) ═══════════════════════
d00.rol_esquema.read          — consultar la estructura canónica de campos del RolTemplate
d00.rol_esquema.configure     — configurar el molde (solo SU/SYS — estructura, no instancias)

═══ ROL — CAPA PARTICULAR (valores de un rol específico) ════════════════
d00.rol_entidad.create        — registrar un rol en el árbol organizacional
d00.rol_entidad.read          — leer los valores concretos de un rol (org_unit_id, sector_code…)
d00.rol_entidad.configure     — editar accountability_chain, vigencia, aprobadores del rol
d00.rol_entidad.delete        — retirar un rol del árbol (ciclo JML offboarding de rol)

═══ USUARIO — CAPA GENERAL (el molde del UserTemplate) ══════════════════
d00.usuario_esquema.read      — consultar la estructura canónica de campos del UserTemplate
d00.usuario_esquema.configure — configurar el molde de usuario (solo SU/SYS)

═══ USUARIO — CAPA PARTICULAR (valores de un usuario específico) ════════
d00.usuario_entidad.create    — dar de alta un usuario en el árbol (ciclo JML onboarding)
d00.usuario_entidad.read      — leer datos concretos de un usuario (uuid, department, manager…)
d00.usuario_entidad.configure — editar posición, reporting_line, metadatos de posición
d00.usuario_entidad.delete    — baja del usuario (ciclo JML offboarding)

═══ TRANSVERSALES — siempre PARTICULAR (ROL y/o USUARIO) ════════════════
d00.atributos.read            — leer atributo extendido de una entidad (Motor de Identidad)
d00.atributos.write           — escribir atributo de una entidad (LoA mínimo AAL2)
d00.atributos.validate        — verificar unicidad/formato según reglas del tenant

d00.proofing.validate         — verificar el IAL alcanzado por el usuario específico
d00.proofing.approve          — aprobación manual de evidencia (IAL3)
d00.proofing.configure        — configurar IAL requerido por servicio (SP 800-63-4 §4.2)

d00.consentimiento.write      — [GAP] registrar/actualizar consentimiento del usuario
d00.consentimiento.read       — [GAP] consultar estado de consentimiento
d00.consentimiento.delete     — [GAP] ejercer derecho de supresión (GDPR Art. 17)

d00.verifiable_credential.issue  — [GAP] emitir VC sobre atributos del sujeto
d00.verifiable_credential.verify — [GAP] verificar VC presentada por el sujeto
d00.verifiable_credential.revoke — [GAP] revocar VC emitida

d00.fal.configure    — [GAP] configurar FAL requerido por federación de identidad
d00.fal.validate     — [GAP] verificar que la aserción OIDC/SAML cumple el FAL
```

### 2.4 Gaps D00

| # | Gap | Prioridad |
|---|-----|-----------|
| G-D00-01 | Bloque `consentimiento` faltante — GDPR Art. 6 + SP 800-63-4 §10 (obligatorio en IAL2+) | P1 |
| G-D00-02 | Sección `identity_proofing` del UserTemplate sin materializar en DDL — A.02 §19.2-U1 especificada, no implementada | **P0** — SP 800-63-4 Final: IAL modular exigible ahora |
| G-D00-03 | Bloque `fal` faltante — SP 800-63-4 §5 introduce FAL como 3ª dimensión formal (FAL1/2/3); bAuth como IdP OIDC debe declararlo | **P1** (era P2) |
| G-D00-04 | Bloque `verifiable_credential` faltante — W3C VCDM 2.0 es W3C Recommendation desde mayo 2025; eIDAS 2.0 lo adopta para EUDI Wallet | P2 (era P3) |

---

## 3. D01 — Acceso Lógico

**Propósito:** autenticación y autorización digital — sesiones, tokens, step-up, MFA, zonas
de aplicación, campos de datos, contratos de acceso. FastPath puro (<0.5 ns, bit directo).
221 roles (de SU a BIZ_N5, con LoA 3→1 según tier).

**Pipeline:** FAST-PATH — primer plano evaluado tras las pre-condiciones.

**Estándar principal:** NIST SP 800-63B-4 (AAL1–3) · ANSI INCITS 359:2012 R2022 (RBAC) ·
RFC 9470 (Step-Up Authentication) · OpenID CAEP 1.0 Final (2025) · Gartner IGA 2025

### 3.1 Bloques canónicos

| Bloque | Descripción | Norma | Estado |
|--------|-------------|-------|--------|
| `authorization` | Evaluación PDP — ¿puede hacer esto ahora? | INCITS 359 §3 · NIST AC-3 | ✅ |
| `roles` | Gestión del ciclo de vida de roles RBAC | INCITS 359 §4 · NIST AC-2 | ✅ |
| `zones` | Control de acceso a zonas de aplicación (record/field/button/data) | NIST AC-3(7) ZTA | ✅ |
| `fields` | Acceso a campos de datos con enmascaramiento y obligaciones PII | NIST AC-3(9) · ISO 27001 A.8.11 | ✅ |
| `contracts` | Contratos de modo de acceso (READ_ONLY, APPEND_ONLY, etc.) | ISO/IEC 15408-2 · NIST AC-4 | ✅ |
| `certification` | Recertificación periódica de accesos (IGA — entitlement review) | NIST AC-2(7) · ISO 27002:2022 §5.18 · CIS v8.1 Control 6 | ❌ FALTANTE |
| `session` | Gestión del ciclo de vida de sesión lógica — `session-revoked` y `token-claims-change` son tipos formales de CAEP 1.0 Final (sep 2025) | NIST AC-12 · CAEP 1.0 Final (sep 2025) | ⚠️ parcial |
| `dynamic_policy` | Políticas dinámicas ABAC/PBAC — `authorization_details` estructurados (RFC 9396 RAR) + NIST CSF 2.0 PR.AA-04 (identity assertions verified dinámicamente) | NIST CSF 2.0 PR.AA-04 · RFC 9396 (RAR) | ❌ FALTANTE |
| `Zona de Negocios` | Contenedor de aplicaciones del dominio lógico — registra qué apps operan en este perímetro de control (prefijo `zona_logical_*`); acepta solo nodos `politica` de app con Z0·Identidad (`app_code`, `vendor`, `slug_prefix`). Jerarquía interna: zona → model / actions / field / button / record_rule (5 niveles Tryton). Rechaza departamentos y categorías abstractas. Definición canónica: A.67 §3–§5.1 | NGAC INCITS 565-2020 §4 · SABSA SCF · ISO/IEC 27001:2022 A.5.15 · XACML 3.0 §5.2 | ✅ parcial (5 apps registradas — ver A.67) |

### 3.2 Hallazgo: IGA como capacidad de D01 (no dominio nuevo)

IGA responde *"¿debería seguir teniendo este acceso?"* (revisión periódica), distinto de
`authorization` que responde *"¿puede hacer esto ahora?"* (runtime).

El Gartner Market Guide for IGA 2025–2026 enfatiza que los programas IGA fallan cuando
no capturan el crecimiento real de *entitlement sprawl* — cada `privilege_atom_grant`
con `status = 'ACTIVE'` es candidata a campaña de recertificación. NIST AC-2(7) exige
revisión periódica de privilegios. El bloque `certification` en D01 implementa esto.

### 3.3 Átomos de referencia

```
d01.authorization.approve    — PDP: aprobar acceso a recurso
d01.authorization.execute    — PDP: ejecutar acción autorizada
d01.roles.create             — crear rol en el catálogo
d01.roles.assign             — asignar rol a sujeto
d01.roles.delegate           — delegar capacidad de gestión de rol
d01.zones.access             — acceder a zona de aplicación
d01.zones.configure          — configurar política de zona
d01.fields.read              — leer campo con masking si aplica
d01.fields.export            — exportar campo (LoA elevado requerido)
d01.contracts.configure      — definir contrato de modo de acceso
d01.certification.approve    — recertificar un grant existente (IGA)
d01.certification.audit      — reporte de entitlement sprawl
d01.dynamic_policy.configure — [GAP] definir reglas de política dinámica (ABAC/PBAC)
d01.dynamic_policy.evaluate  — [GAP] evaluar request contra política dinámica
```

### 3.4 Gaps D01

| # | Gap | Prioridad |
|---|-----|-----------|
| G-D01-01 | Bloque `certification` (IGA) faltante — NIST AC-2(7) + ISO 27002:2022 §5.18 + CIS v8.1 Control 6 | P1 |
| G-D01-02 | Bloque `session` incompleto — implementar tipos de evento CAEP 1.0 Final (sep 2025): `session-revoked`, `token-claims-change` | P1 |
| G-D01-03 | Bloque `dynamic_policy` faltante — NIST CSF 2.0 PR.AA-04 + RFC 9396 RAR | P2 |

---

## 4. D02 — Acceso Físico

**Propósito:** PACS (Physical Access Control Systems) — zonas físicas, controladores OSDP,
credenciales temporales, anti-passback. ~30 roles (portero, administrador PACS, AASANA,
aduana). FastPath + canal OSDP AES-128/256.

**Pipeline:** FAST-PATH — evaluación por bit directa tras D01.

**Estándar principal:** IEC 60839-11-5:2020 (OSDP v2) · SIA OSDP v2.2.2 (oct 2024) ·
NIST SP 800-116 Rev.1 (PIV para PACS) · ISO 19092:2008 (seguridad física)

### 4.1 Bloques canónicos

| Bloque | Descripción | Norma | Estado |
|--------|-------------|-------|--------|
| `facilities` | Acceso a instalaciones físicas — puertas, torniquetes, barreras | IEC 60839-11-5:2020 §6 · ISO 19092 §7 | ✅ |
| `readers` | Configuración y auditoría de lectores OSDP — firmware, canal seguro | SIA OSDP v2.2.2 §4 · IEC 60839-11-5:2020 §8 | ✅ |
| `presence` | Verificación de presencia dual (mantrap, anti-passback) | NIST SP 800-116 R1 §4.3 · ISO 19092 §9 | ✅ |
| `visitors` | Acceso temporal a terceros no empleados con auto-expiración | ISO 19092:2008 §8 · NIST AC-2(2) | ❌ FALTANTE |
| `emergency` | Acceso de emergencia físico (break-glass físico) | NIST AC-17(3) · ISO 19092 §10 | ❌ FALTANTE |
| `antipassback` | Prevención de reutilización de credencial en misma sesión física | IEC 60839-11-5:2020 §7.4 | ⚠️ implícito en `presence` |
| `mustering` | Evacuación de emergencia — conteo de personal dentro de zona; ¿quién salió, quién no? | NIST SP 800-116 R1 §4.4 · ISO 45001:2018 (OH&S) | ❌ FALTANTE |
| `Zona de Negocios` | Contenedor de aplicaciones del dominio físico — registra qué sistemas de control de acceso físico (PACS, lectores, actuadores) operan en este perímetro (prefijo `zona_fisica_*`); acepta solo nodos `politica` con Z0·Identidad. Niveles internos: device_access / location_rule / schedule_rule. Definición canónica: A.67 §3–§5.2 | NGAC INCITS 565-2020 §4 · SABSA SCF · ISO/IEC 27001:2022 A.5.15 · XACML 3.0 §5.2 | ❌ definir apps D02 |

### 4.2 Novedad: SIA OSDP v2.2.2 (octubre 2024)

SIA OSDP v2.2.2 fue publicada en octubre 2024 como la versión más reciente del estándar
de comunicación segura entre ACU (Access Control Unit) y dispositivos periféricos (lectores,
teclados). Cambios relevantes: mejoras al canal seguro SC (refuerzo AES-256 GCM),
simplificación del handshake para dispositivos embebidos de baja potencia, y extensiones
para biometría on-reader (integración D05 → D02).

### 4.3 Átomos de referencia

```
d02.facilities.access       — acceder a instalación física
d02.facilities.configure    — configurar política de zona física
d02.facilities.audit        — auditar eventos de acceso físico
d02.readers.configure       — configurar lector OSDP (canal seguro, firmware)
d02.readers.audit           — auditar estado de lector (online/offline, tamper)
d02.presence.validate       — verificar presencia dual / anti-passback
d02.visitors.create         — crear credencial temporal para visitante
d02.visitors.delete         — revocar credencial de visitante (expiración forzada)
d02.emergency.approve       — aprobación dual para break-glass físico
d02.mustering.execute       — [GAP] activar conteo de evacuación (¿quién sigue dentro?)
d02.mustering.validate      — [GAP] verificar que todos los registros de presencia han salido
```

### 4.4 Gaps D02

| # | Gap | Prioridad |
|---|-----|-----------|
| G-D02-01 | Bloque `visitors` faltante — ciclo de vida de acceso temporal a terceros | P1 |
| G-D02-02 | Bloque `emergency` (break-glass físico) no modelado | P2 |
| G-D02-03 | Anti-passback implícito en `presence` — debe ser bloque propio | P2 |
| G-D02-04 | Integración biometría on-reader (OSDP v2.2.2) no diseñada — enlace D05→D02 | P3 |

---

## 5. D03 — Financiero

**Propósito:** límites transaccionales, aprobación dual, SoD financiero, facturación
electrónica Bolivia (SIN). ~115 roles (tesorería, SWIFT, pasarelas, factoring, casa de
cambios, facturas electrónicas SIN).

**Pipeline:** POLICY-PATH — evaluación con PolicyChain completa.

**Estándar principal:** PCI DSS 4.0.1 (2024, reemplaza 3.2.1 retirado mar 2024) ·
SOX §404 (control interno sobre reportes financieros) · COSO 2013 (control interno) ·
ISO 20022:2022 (mensajería financiera) · SIN RND 10-0025-23 (Bolivia)

### 5.1 Bloques canónicos

| Bloque | Descripción | Norma | Estado |
|--------|-------------|-------|--------|
| `limits` | Límites transaccionales — monto máximo, frecuencia, acumulado diario | PCI DSS 4.0.1 Req 7 · COSO §CC6.3 | ✅ |
| `approvals` | Aprobación dual / quórum k-de-N para transacciones de alto valor | SOX §404 · NIST AC-5 · COSO §CC7.2 | ✅ |
| `segregation` | SoD financiero — separación capturador/aprobador/conciliador | SOX §404 · COSO Control Activities · NIST AC-5 | ✅ |
| `billing` | Factura electrónica Bolivia SIN (CUIS, CUFD, SIAT) | SIN RND 10-0025-23 · DS 27310 | ✅ |
| `reporting` | Reportes regulatorios — conciliación, cierre, SWIFT MT940 | SOX §302 · ISO 20022:2022 | ❌ FALTANTE |
| `fraud` | Detección de anomalías transaccionales (velocidad, monto, geografía) — PCI DSS 4.0.1 Req 10.7.3 exige detección de fallos en tiempo real con alerta automatizada | PCI DSS 4.0.1 Req 10.7.3 · COSO §CC7.3 | ❌ FALTANTE |
| `reconciliation` | Conciliación automática de cuentas y posiciones | COSO §CC7.4 · ISO 20022:2022 §5 | ❌ FALTANTE |
| `open_banking` | Consentimiento granular de acceso a cuenta bancaria (OBL v4.0 + FAPI 2.0) — consent token, scope de cuenta, validez | Open Banking Standard v4.0 · FAPI 2.0 (OIDF) · ISO 20022 | ❌ FALTANTE |
| `Zona de Negocios` | Contenedor de aplicaciones del dominio financiero — registra módulos financieros (account, invoice, payment de Tryton; pasarelas de pago; SIAT) con prefijo `zona_financial_*`; acepta solo nodos `politica` con Z0·Identidad. Niveles: model / actions / field / button / record_rule. Nota: módulos `account_*` de Tryton van aquí, NO en D01. Definición canónica: A.67 §3–§5.3 | NGAC INCITS 565-2020 §4 · SABSA SCF · ISO/IEC 27001:2022 A.5.15 · PCI DSS 4.0.1 Req 7 | ❌ definir apps D03 |

### 5.2 Hallazgo: PCI DSS 4.0.1 — cambios que impactan D03

PCI DSS 3.2.1 fue retirado el 31 de marzo de 2024. La versión 4.0.1 vigente introduce:
- **Req 7 revisado:** acceso a datos de tarjeta debe ser estrictamente need-to-know con
  revisión formal al menos cada 6 meses — mapea al bloque `certification` de D01.
- **Req 10.7.3:** se exige detección de fallos de controles de seguridad en tiempo real
  con alerta automatizada — impacta D03 `fraud` y D11 `monitoring`.
- **Ambiente separado produción/preproducción** con aprobaciones explícitas — SoD en CI/CD.
- Énfasis en **Zero Trust para acceso a datos de pago** — integración D07→D03.

### 5.3 Átomos de referencia

```
d03.limits.configure        — configurar límite transaccional (monto/frecuencia)
d03.limits.approve          — aprobación de excepción de límite
d03.approvals.approve       — aprobación dual (quórum k-de-N, obligation de LoA)
d03.approvals.delegate      — delegar capacidad de aprobación financiera
d03.segregation.validate    — verificar SoD antes de asignar rol financiero
d03.segregation.configure   — configurar matriz de conflictos SoD
d03.billing.emit            — emitir factura electrónica SIN (SIAT)
d03.billing.validate        — validar factura electrónica
d03.billing.audit           — consultar historial de facturas
d03.reporting.read          — consultar reporte regulatorio
d03.reporting.emit          — generar cierre/conciliación
d03.fraud.validate          — evaluar señal de fraude en transacción
d03.reconciliation.execute  — ejecutar conciliación automática
d03.open_banking.consent_create — [GAP] crear consentimiento de acceso a cuenta bancaria
d03.open_banking.consent_revoke — [GAP] revocar consentimiento
d03.open_banking.validate       — [GAP] verificar scope de acceso OB antes de operar
```

### 5.4 Gaps D03

| # | Gap | Prioridad |
|---|-----|-----------|
| G-D03-01 | Bloque `reporting` faltante — SOX §302 y requerimientos regulatorios | P1 |
| G-D03-02 | Bloque `fraud` faltante — PCI DSS 4.0.1 Req 10.7.3 obligatorio desde mar 2025 | **P0** (era P1) |
| G-D03-03 | Bloque `reconciliation` faltante — COSO §CC7.4 | P2 |
| G-D03-04 | Integración D07→D03 (Zero Trust para datos de pago) no modelada | P2 |
| G-D03-05 | Bloque `open_banking` faltante — OBL v4.0 + FAPI 2.0 si se integran entidades bancarias | P2 |
| G-D03-04 | Integración D07→D03 (Zero Trust para datos de pago) no modelada | P2 |

---

## 6. D04 — Temporal

**Propósito:** horarios, turnos, feriados, ventanas temporales de acceso. El cajero entra
solo en su turno; el batch nocturno corre solo entre 23:00 y 04:00. 155 roles (N4+N5).
Sin átomos propios — encadenado a D01 vía PolicyChainResolver.

**Pipeline:** POLICY-PATH — encadenado a átomos D01.

**Estándar principal:** GTRBAC — Generalized Temporal RBAC (Bertino et al., IEEE TDKE 2005) ·
RFC 5545 iCalendar (IETF, vigente) · ISO 8601:2019 (fechas y duraciones)

### 6.1 Bloques canónicos

| Bloque | Descripción | Norma | Estado |
|--------|-------------|-------|--------|
| `windows` | Ventanas de tiempo válidas para acceso — horario laboral, turnos | GTRBAC §3 (role enabling) · ISO 8601 §4 | ✅ |
| `periods` | Duración de asignación temporal — expiración de rol/permiso | GTRBAC §4 (duration constraints) · ISO 8601 §5 | ✅ |
| `calendar` | Calendario de feriados y excepciones por país/tenant | RFC 5545 §3.8 (VTIMEZONE, VEVENT) · ISO 8601 | ✅ |
| `schedules` | Rotación de turnos (mañana/tarde/noche) con herencia temporal | GTRBAC §5 (periodicity constraints) | ❌ FALTANTE |
| `exceptions` | Excepciones de horario — horas extra, guardia, emergencia | GTRBAC §6 · NIST AC-17(3) | ❌ FALTANTE |
| `Zona de Negocios` | Contenedor de aplicaciones del dominio temporal — registra sistemas de calendario, gestión de turnos y schedulers con prefijo `zona_temporal_*`; acepta solo nodos `politica` con Z0·Identidad. Niveles: time_window / calendar_rule / expiry_policy. Definición canónica: A.67 §3–§5.4 | NGAC INCITS 565-2020 §4 · SABSA SCF · ISO/IEC 27001:2022 A.5.15 · XACML 3.0 §5.2 | ❌ definir apps D04 |

### 6.2 Nota sobre GTRBAC

GTRBAC es la referencia académica correcta y sigue siendo el modelo más completo para
RBAC con restricciones temporales. No hay reemplazo formal ISO/NIST dedicado — la norma
NIST SP 800-53 AC-2(2) y AC-12 mencionan expiración de cuentas/sesiones pero no el modelo
completo de ventanas/períodos/calendarios.

**Los tres estados de rol de GTRBAC** (`disabled` / `enabled` / `active`) mapean
directamente al ciclo de vida de átomos de bAuth en el árbol.

### 6.3 Átomos de referencia

```
d04.windows.configure       — configurar ventana temporal de acceso
d04.windows.validate        — ¿el request cae dentro de la ventana activa?
d04.periods.configure       — duración de asignación (con fecha de expiración)
d04.periods.validate        — ¿expiró el período de asignación?
d04.calendar.configure      — registrar calendario de feriados del tenant
d04.calendar.read           — consultar días hábiles / excepciones
d04.schedules.configure     — configurar rotación de turnos
d04.schedules.assign        — asignar turno a usuario
d04.exceptions.approve      — aprobar excepción de horario (guardia/emergencia)
```

### 6.4 Gaps D04

| # | Gap | Prioridad |
|---|-----|-----------|
| G-D04-01 | Bloque `schedules` (rotación de turnos) faltante — GTRBAC §5 | P2 |
| G-D04-02 | Bloque `exceptions` (horas extra / guardia) faltante — GTRBAC §6 | P2 |

---

## 7. D05 — Biométrico

**Propósito:** enrolamiento biométrico, verificación (match contra template), detección de
ataques de presentación (PAD/liveness). ~34 roles (enrolador, verificador SEGIP/migración,
antispoofing). El binario biométrico NUNCA entra a bAuth — solo referencias `ref://`.
External-Path vía bhnexus.

**Pipeline:** EXTERNAL-PATH — vía bhnexus hacia motor biométrico externo.

**Estándar principal:** ISO/IEC 30107-3:2023 (PAD — Presentation Attack Detection) ·
ISO/IEC 30107-1:2016 (marco general) · NIST SP 800-63B-4 §5.2.3 (biometric AAL3) ·
ISO/IEC 19794 (formatos de datos biométricos)

### 7.1 Bloques canónicos

| Bloque | Descripción | Norma | Estado |
|--------|-------------|-------|--------|
| `enrollment` | Captura y registro de template biométrico | ISO/IEC 19794-2 · SP 800-63A-4 §5 (IAL3) | ✅ |
| `verification` | Comparación 1:1 contra template registrado | ISO/IEC 30107-1 §5 · SP 800-63B-4 §5.2.3 | ✅ |
| `liveness` | Detección de ataque de presentación (PAD) y anti-spoofing | ISO/IEC 30107-3:2023 (APAR/BPAR/RIAPAR) | ✅ |
| `identification` | Comparación 1:N (buscar en base de templates) | ISO/IEC 30107-1 §6 · INTERPOL standards | ❌ FALTANTE |
| `quality` | Verificación de calidad del sample biométrico antes de capturar | ISO/IEC 29794-1:2024 (calidad de muestra) | ❌ FALTANTE |
| `revocation` | Revocación de template biométrico comprometido | SP 800-63B-4 §8.3 · ISO/IEC 24745 | ❌ FALTANTE |
| `Zona de Negocios` | Contenedor de aplicaciones del dominio biométrico — registra sistemas de captura y verificación biométrica con prefijo `zona_biometric_*`; acepta solo nodos `politica` con Z0·Identidad. Niveles: biometric_method / liveness_check / fallback_policy. Definición canónica: A.67 §3–§5.4 | NGAC INCITS 565-2020 §4 · SABSA SCF · ISO/IEC 27001:2022 A.5.15 · XACML 3.0 §5.2 | ❌ definir apps D05 |

### 7.2 Hallazgo: ISO/IEC 30107-3 versión 2023

La revisión 2023 agrega la métrica **RIAPAR** (Relative Impact of Attacks Per Recognition
Attempt Rate) que mide el impacto real en el mundo de los ataques de presentación,
considerando tanto las detecciones exitosas como la tasa de falsa aceptación a legítimos.
Anterior a esta revisión, solo APAR y BPAR eran las métricas canónicas.

El **TÜV Rheinland** certificó productos al nivel **ISO/IEC 30107-3 Level C** (el más alto)
en 2025, estableciendo un precedente para conformidad auditable.

**Inyección de ataque (IAD — Injection Attack Detection)** fue incorporada como
categoría formal a partir de la revisión 2023 — los ataques digitales (bypass de cámara
vía inyección de video) son tan relevantes como los físicos (máscara, foto impresa).

### 7.3 Átomos de referencia

```
d05.enrollment.create       — capturar y registrar template biométrico
d05.enrollment.delete       — eliminar template biométrico
d05.enrollment.audit        — auditar enrolamientos por período
d05.verification.validate   — match 1:1 contra template registrado
d05.liveness.validate       — PAD: detectar ataque de presentación
d05.identification.search   — match 1:N en base de templates
d05.quality.validate        — verificar calidad del sample antes de capturar
d05.revocation.execute      — revocar template biométrico comprometido
```

### 7.4 Gaps D05

| # | Gap | Prioridad |
|---|-----|-----------|
| G-D05-01 | Bloque `quality` faltante — ISO/IEC 29794-1:**2024** publicada; ya no es gap académico, es norma ISO formal | **P0** (era P1) |
| G-D05-02 | Bloque `revocation` faltante — SP 800-63B-4 §8.3 | P1 |
| G-D05-03 | Bloque `identification` (1:N) faltante — SEGIP/migración casos de uso | P2 |
| G-D05-04 | IAD (Injection Attack Detection) debe diferenciarse de PAD — **ahora es [N] ISO/IEC 30107-3:2023** (no `🔬` emergente) | P2 |

---

## 8. D06 — Geoespacial

**Propósito:** geocercas, viaje imposible, flotas, soberanía de datos por jurisdicción.
~54 roles. Encadenado a D01 vía PolicyChainResolver. External-Path.

**Pipeline:** EXTERNAL-PATH — encadenado a átomos D01.

**Estándar principal:** OGC GeoFence (Open Geospatial Consortium) · BeyondCorp (Zero Trust
Google) · NIST SP 800-207 §3.3 (localización como señal de contexto) · ISO 19115-1:2014
(metadatos geográficos)

### 8.1 Bloques canónicos

| Bloque | Descripción | Norma | Estado |
|--------|-------------|-------|--------|
| `geofencing` | Definición y evaluación de geocercas — ¿está el sujeto dentro? | OGC GeoFence v1.0 · ISO 19115-1 | ✅ |
| `location` | Validación de ubicación puntual del sujeto | OGC GeoFence · BeyondCorp §4 | ✅ |
| `velocity` | Detección de viaje imposible (>900 km/h entre dos autenticaciones) | UEBA patrón industria · NIST SP 800-207 §3.3 | ✅ |
| `residency` | Soberanía de datos — ¿el procesamiento respeta la jurisdicción de origen? | GDPR Art. 44–49 · Ley 1174 Bolivia | ❌ FALTANTE |
| `fleet` | Gestión de acceso basada en ubicación de flota (vehículos, drones) | OGC MovingFeatures · ISO 19141 | ❌ FALTANTE |
| `Zona de Negocios` | Contenedor de aplicaciones del dominio geoespacial — registra sistemas de geofencing, mapas y control de ubicación con prefijo `zona_geo_*`; acepta solo nodos `politica` con Z0·Identidad. Niveles: geofence / country_rule / ip_region_rule. Definición canónica: A.67 §3–§5.4 | NGAC INCITS 565-2020 §4 · SABSA SCF · ISO/IEC 27001:2022 A.5.15 · XACML 3.0 §5.2 | ❌ definir apps D06 |

### 8.2 Nota: `velocity` como patrón de industria

El "viaje imposible" es un patrón UEBA (User and Entity Behavior Analytics) ampliamente
adoptado pero sin número de norma ISO/NIST propio. Su referencia correcta es NIST SP 800-207
§3.3 (señales de contexto para ZTA) y los algoritmos de Okta/Microsoft/Google que lo
implementan. Documentarlo como patrón de industria, no norma, es la posición correcta.

### 8.3 Átomos de referencia

```
d06.geofencing.configure    — definir geocerca (polígono GeoJSON)
d06.geofencing.validate     — ¿el sujeto está dentro de la geocerca permitida?
d06.location.validate       — validar ubicación puntual
d06.velocity.validate       — detectar viaje imposible
d06.residency.validate      — ¿el procesamiento cumple la jurisdicción de origen?
d06.residency.configure     — configurar reglas de soberanía por tenant/dominio
d06.fleet.validate          — verificar ubicación de activo de flota
```

### 8.4 Gaps D06

| # | Gap | Prioridad |
|---|-----|-----------|
| G-D06-01 | Bloque `residency` faltante — soberanía de datos, principio SBOS | P1 |
| G-D06-02 | Bloque `fleet` faltante — vehículos/drones/activos con identidad geográfica | P3 |

---

## 9. D07 — Red

**Propósito:** ZTNA (Zero Trust Network Access) — CIDR, VPN, mTLS, postura del dispositivo,
rate limiting. External-Path vía Kong (PEP de borde). Sin roles propios directos; todos
los roles pasan por D07 en borde.

**Pipeline:** EXTERNAL-PATH — Kong es el PEP, bAuth el PDP.

**Estándar principal:** NIST SP 800-207:2020 (ZTA) + 800-207A (cloud-native ZTA) ·
IEEE 802.1X-2020 (acceso a red por puerto) · RFC 9449 (DPoP) · RFC 8705 (mTLS OAuth 2.0) ·
OpenID CAEP 1.0 (señales de red en tiempo real)

### 9.1 Bloques canónicos

| Bloque | Descripción | Norma | Estado |
|--------|-------------|-------|--------|
| `connection` | Validación de conexión — mTLS presente, CIDR permitido | NIST SP 800-207 §4 · RFC 8705 | ✅ |
| `tokens` | Proof-of-Possession de token (DPoP/PKCE) para evitar replay | RFC 9449 (DPoP) · RFC 7636 (PKCE) | ✅ |
| `rate` | Rate limiting por usuario/IP/ruta — prevención de abuse | OWASP API Security §4 · NIST SI-10 | ✅ |
| `posture` | Postura de red del punto de conexión (segmento, VPN, reputación IP) | NIST SP 800-207 §3.2 · BeyondCorp | ❌ FALTANTE |
| `segmentation` | Micro-segmentación de red — east-west traffic control | NIST SP 800-207A §4 · CISA ZT Pillar | ❌ FALTANTE |
| `inspection` | Inspección de payload en tránsito (DPI/DLP para datos sensibles) | NIST SP 800-207 §4.4 · PCI DSS 4.0.1 Req 4 | ❌ FALTANTE |
| `propagation` | Propagación de contexto inter-servicio con headers estándar W3C (`traceparent`, `tracestate`, Baggage). Sin este bloque la observabilidad distribuida de SBOS es incompleta | W3C Trace Context v2 (Rec) · W3C Baggage (Rec) · OpenTelemetry Propagation API | ❌ FALTANTE |
| `Zona de Negocios` | Contenedor de aplicaciones del dominio de red — registra sistemas de conectividad, proxies y gateways con prefijo `zona_network_*`; acepta solo nodos `politica` con Z0·Identidad. Niveles: network_segment / protocol_rule / port_policy. Definición canónica: A.67 §3–§5.4 | NGAC INCITS 565-2020 §4 · SABSA SCF · ISO/IEC 27001:2022 A.5.15 · NIST SP 800-207 §3.3 | ❌ definir apps D07 |

### 9.2 Novedad: NIST SP 800-207A (cloud-native ZTA)

NIST SP 800-207A amplía 800-207 con guía específica para aplicaciones cloud-native en
entornos multi-cloud. Relevante para SBOS si en el futuro algunos daemons corren en
entornos híbridos. El modelo de **identity-based micro-segmentation** de 207A es coherente
con la arquitectura de Kong como PEP.

### 9.3 Átomos de referencia

```
d07.connection.validate     — mTLS presente, CIDR dentro del rango permitido
d07.connection.configure    — configurar políticas de conexión por servicio
d07.tokens.validate         — verificar DPoP/PKCE proof-of-possession
d07.rate.configure          — configurar límite de tasa por ruta/usuario
d07.rate.validate           — ¿excedió el límite de tasa?
d07.posture.validate        — postura de red: VPN activa, segmento correcto, reputación IP
d07.segmentation.configure  — definir regla de micro-segmentación
d07.inspection.configure    — configurar DLP para ruta/payload
d07.propagation.configure   — [GAP] configurar headers W3C Trace Context por servicio
d07.propagation.validate    — [GAP] verificar que traceparent llega íntegro al destino
```

### 9.4 Gaps D07

| # | Gap | Prioridad |
|---|-----|-----------|
| G-D07-01 | Bloque `posture` faltante — NIST SP 800-207 §3.2 + CISA ZTA Maturity Model v2.0 | P1 |
| G-D07-04 | Bloque `propagation` faltante — W3C Trace Context v2 + OTel Baggage (era "implícito en ctx_id") | P2 |
| G-D07-02 | Bloque `segmentation` faltante — NIST SP 800-207A §4 | P2 |
| G-D07-03 | Bloque `inspection` (DLP en tránsito) faltante — PCI DSS 4.0.1 Req 4 | P2 |

---

## 10. D08 — Contexto / Sesión

**Propósito:** el ctx_id como pre-condición — sin contexto vivo no hay evaluación.
Contexto de sesión, riesgo continuo, postura de dispositivo, acceso de emergencia.
Pre-BitMask: falla antes de evaluar cualquier bit.

**Pipeline:** PRE-BITMASK — primer bloque del pipeline, antes de D09.

**Estándar principal:** SBOS-049 (Context Plane) · W3C Trace Context v2 ·
OpenID CAEP 1.0 Final (2025) — eventos: `Session Revoked`, `Risk Level Change`,
`Device Compliance Change`, `Assurance Level Change` · NIST AC-17(3) (acceso emergencia)

### 10.1 Bloques canónicos

| Bloque | Descripción | Norma | Estado |
|--------|-------------|-------|--------|
| `session` | Ciclo de vida del ctx_id — creación, validación, revocación | SBOS-049 · CAEP `Session Revoked` | ✅ |
| `risk` | Score de riesgo continuo del sujeto — señales de comportamiento | CAEP `Risk Level Change` · NIST AC-17 | ✅ |
| `device` | Postura del dispositivo — MDM, parches, cifrado en reposo | CAEP `Device Compliance Change` · NIST AC-19 | ✅ |
| `emergency` | Break-glass — acceso con doble aprobación a contextos protegidos | NIST AC-17(3) · ISO 27001 A.8.18 | ✅ |
| `assurance` | Nivel de garantía de la sesión activa (current_loa) — `assurance-level-change` es tipo de evento formal en CAEP 1.0 Final (sep 2025) | CAEP 1.0 Final (sep 2025) · SP 800-63B-4 §4 | ❌ FALTANTE |
| `itdr` | Identity Threat Detection and Response — investigación retrospectiva de incidentes de identidad (Golden Ticket, movimiento lateral, abuso de sesión). Distinto de `risk` (evaluación continua) | NIST SP 800-53 R5.2 IR-4 · Gartner ITDR 2025 [I] | ❌ FALTANTE |
| `Zona de Negocios` | Contenedor de aplicaciones del dominio de contexto/sesión — registra sistemas de gestión de contexto y riesgo con prefijo `zona_context_*`; acepta solo nodos `politica` con Z0·Identidad. Niveles: device_trust / risk_score_rule / session_context. Definición canónica: A.67 §3–§5.4 | NGAC INCITS 565-2020 §4 · SABSA SCF · ISO/IEC 27001:2022 A.5.15 · XACML 3.0 §5.2 | ❌ definir apps D08 |

### 10.2 Hallazgo: CAEP 1.0 Final (2025) — eventos estandarizados

La especificación **OpenID CAEP 1.0** (publicada final en 2025, parte del Shared Signals
Framework) define tipos de evento formales que mapean directamente a los bloques de D08:

| Evento CAEP canónico | Bloque D08 | Descripción |
|---|---|---|
| `session-revoked` | `session` | Terminación forzada de sesión |
| `risk-level-change` | `risk` | Cambio en score de riesgo del sujeto |
| `device-compliance-change` | `device` | Cambio en postura del dispositivo (MDM/EDR) |
| `assurance-level-change` | `assurance` | Cambio en LoA de la sesión activa |
| `token-claims-change` | `session` | Cambio en claims del token activo |

**Recomendación:** usar los nombres CAEP canónicos como vocabulario de eventos, no
inventar nomenclatura propietaria, para asegurar interoperabilidad con EDR/CASB externos.

### 10.3 ITDR como extensión de `risk` (no dominio nuevo)

**ITDR** (Identity Threat Detection and Response) es la categoría de mercado 2025–2026
para detección de amenazas basadas específicamente en señales de identidad (movimiento
lateral via credenciales, Golden Ticket, abuso de sesión). Encaja como extensión del
bloque `risk` existente en D08:

```
d08.risk.audit              — investigación de incidente de identidad (ITDR forense)
d08.risk.execute            — respuesta automática: forzar step-up o revocar sesión
```

### 10.4 Átomos de referencia

```
d08.session.validate        — ¿ctx_id vivo y válido?
d08.session.delete          — revocar sesión (CAEP session-revoked)
d08.risk.validate           — evaluar score de riesgo actual del sujeto
d08.risk.audit              — investigar incidente de identidad (ITDR)
d08.risk.execute            — respuesta automática ante señal de compromiso
d08.device.validate         — ¿dispositivo cumple postura requerida?
d08.device.configure        — configurar requisitos de postura por servicio
d08.emergency.approve       — aprobación dual para break-glass (NIST AC-17(3))
d08.assurance.validate      — [GAP] ¿la sesión activa cumple el LoA requerido? (CAEP assurance-level-change)
d08.itdr.investigate        — [GAP] iniciar investigación de incidente de identidad
d08.itdr.remediate          — [GAP] ejecutar remediación (forzar re-auth, revocar sesiones cruzadas)
d08.itdr.report             — [GAP] generar reporte forense de incidente
```

### 10.5 Gaps D08

| # | Gap | Prioridad |
|---|-----|-----------|
| G-D08-01 | Bloque `assurance` faltante — CAEP 1.0 Final (sep 2025): `assurance-level-change` es tipo de evento estándar formal | **P1** |
| G-D08-02 | Bloque `itdr` faltante — NIST IR-4 + Gartner ITDR 2025; todos los líderes PAM/IGA lo implementan | P1 |

---

## 11. D09 — Credenciales

**Propósito:** ciclo de vida de los métodos de autenticación — enrolamiento, AAL, recovery,
historial de contraseñas, revocación <30 s. Pre-BitMask: ¿la LoA de la sesión alcanza
la que el átomo exige? 18 métodos implementados.

**Pipeline:** PRE-BITMASK — segundo bloque tras D08.

**Estándar principal:** NIST SP 800-63B-4 (final ago 2025) · FIDO2/WebAuthn W3C (2019+) ·
RFC 4226 (HOTP) · RFC 6238 (TOTP) · RFC 5280 (X.509) · RFC 9068 (JWT Access Token)

### 11.1 Bloques canónicos

| Bloque | Descripción | Norma | Estado |
|--------|-------------|-------|--------|
| `password` | Política de contraseña — screening HIBP, Argon2id, historial | NIST SP 800-63B-4 §3.1.1 | ✅ |
| `mfa` | Autenticación multi-factor — TOTP, HOTP, WebAuthn, FIDO Passkey | NIST SP 800-63B-4 §4 · RFC 4226/6238 | ✅ |
| `certificates` | Certificados X.509 — emisión, validación, revocación (OCSP/CRL) | RFC 5280 · NIST SP 800-63B-4 §5.1.3 | ✅ |
| `tokens` | Tokens de acceso/refresco — emisión y revocación | RFC 9068 · RFC 7009 (revocación) | ✅ |
| `revocation` | Revocación de credencial en <30 s | NIST SP 800-63B-4 §8 | ✅ |
| `recovery` | Recuperación de cuenta — códigos de respaldo, flow seguro | NIST SP 800-63B-4 §7.3 · OWASP ASVS §2.2 | ⚠️ parcial |
| `passkey` | FIDO Passkeys (device-bound + synced) — SP 800-63B-4 Final (jul 2025): passkeys resistentes a phishing son la **base de AAL2**, no opción futura | NIST SP 800-63B-4 §4.2 · FIDO Alliance 2025 | ❌ FALTANTE |
| `binding` | Vinculación de autenticador a cuenta (device binding) — obligatorio para Passkeys AAL2 | NIST SP 800-63B-4 §5.2 | ⚠️ implícito |
| `introspection` | Consulta en tiempo real si un token es válido y sus metadatos — necesario para Kong/PEP con tokens opacos | RFC 7662 (OAuth 2.0 Token Introspection) | ❌ FALTANTE |
| `Zona de Negocios` | Contenedor de aplicaciones del dominio de credenciales — registra sistemas de gestión de credenciales, bóvedas y PKI con prefijo `zona_credential_*`; acepta solo nodos `politica` con Z0·Identidad. Niveles: credential_type / rotation_policy / revocation_rule. Definición canónica: A.67 §3–§5.4 | NGAC INCITS 565-2020 §4 · SABSA SCF · ISO/IEC 27001:2022 A.5.15 · XACML 3.0 §5.2 | ❌ definir apps D09 |

### 11.2 Novedad SP 800-63B-4: Passkeys como base de AAL2

La revisión final de SP 800-63B-4 (agosto 2025) establece que **FIDO Passkeys resistentes
a phishing son la recomendación base para AAL2**, no solo el techo de AAL3. Esto implica
que el diseño de D09 debe promover Passkeys como path primario de MFA, con TOTP/HOTP como
fallback, y SMS como método deprecado.

**Passkeys sincronizadas** (ej. iCloud Keychain, Google Password Manager) son AAL2 si el
proveedor de sincronización tiene SSO federation auditable. Passkeys device-bound son AAL3.

### 11.3 Átomos de referencia

```
d09.password.configure      — configurar política de contraseña del tenant
d09.password.validate       — validar contraseña contra política (screening HIBP)
d09.mfa.validate            — verificar factor MFA activo del sujeto
d09.mfa.configure           — configurar métodos MFA permitidos por tier
d09.certificates.validate   — verificar certificado X.509 (OCSP/CRL)
d09.certificates.delete     — revocar certificado
d09.tokens.emit             — emitir access/refresh token (RFC 9068)
d09.tokens.delete           — revocar token (RFC 7009)
d09.revocation.execute      — revocar credencial en <30 s
d09.recovery.execute        — iniciar flujo de recuperación de cuenta
d09.passkey.create          — registrar FIDO Passkey (device-bound o synced)
d09.passkey.delete          — eliminar Passkey registrada
d09.binding.create          — vincular autenticador a cuenta
d09.introspection.validate  — [GAP] consultar validez de token en tiempo real (RFC 7662)
d09.introspection.configure — [GAP] configurar endpoint de introspección y sus clientes
```

### 11.4 Gaps D09

| # | Gap | Prioridad |
|---|-----|-----------|
| G-D09-01 | Bloque `passkey` faltante — SP 800-63B-4 Final (jul 2025): es la **base de AAL2**, no opción futura | **P0** (era P1) |
| G-D09-02 | Bloque `recovery` incompleto — flujo seguro completo (SP 800-63B-4 §7.3 + OWASP ASVS §2.2) | P1 |
| G-D09-03 | Bloque `binding` (device binding) implícito — obligatorio para Passkeys AAL2 | P2 |
| G-D09-04 | Bloque `introspection` faltante — RFC 7662; Kong como PEP necesita para tokens opacos | P1 |

---

## 12. D10 — Delegación

**Propósito:** transferencia temporal de privilegios con **reducción AND** — lo delegado
nunca excede lo propio. DSD (Dynamic Separation of Duty). Tabla `dlg_delegation`.

**Pipeline:** POLICY-PATH — dentro del PolicyChain.

**Estándar principal:** ANSI INCITS 359-2012 R2022 (RBAC — DSD) · NIST SP 800-53 AC-5
(Separation of Duties) · NIST AC-14 (Permitted Actions Without Identification)

### 12.1 Bloques canónicos

| Bloque | Descripción | Norma | Estado |
|--------|-------------|-------|--------|
| `delegation` | Creación y gestión de delegaciones temporales | INCITS 359 §4.5 (DSD) · NIST AC-5 | ✅ |
| `renewal` | Renovación de delegación con revalidación | INCITS 359 §4.5 · NIST AC-2(2) | ✅ |
| `restrictions` | Validación de SoD antes de aprobar delegación | INCITS 359 §4.6 (SSD) · NIST AC-5 | ✅ |
| `chain` | Delegación en cadena — A delega a B que sub-delega a C (con reducción AND). RFC 8693 (Token Exchange) implementa esto: el `actor` claim registra la cadena | INCITS 359 §4.7 · RFC 8693 (Token Exchange) | ❌ FALTANTE |
| `audit` | Trazabilidad de la cadena de delegación | ISO 27001 A.8.15 · NIST AU-2 | ❌ FALTANTE |
| `rich_authorization` | Delegaciones granulares API/M2M programáticas via `authorization_details` estructurado (distinto de `chain` que es delegación humana) | RFC 9396 (RAR, Rich Authorization Requests) | ❌ FALTANTE |
| `Zona de Negocios` | Contenedor de aplicaciones del dominio de delegación — registra sistemas de gestión de delegaciones y consentimiento con prefijo `zona_delegation_*`; acepta solo nodos `politica` con Z0·Identidad. Niveles: delegate_scope / delegation_depth / consent_rule. Definición canónica: A.67 §3–§5.4 | NGAC INCITS 565-2020 §4 · SABSA SCF · ISO/IEC 27001:2022 A.5.15 · XACML 3.0 §5.2 | ❌ definir apps D10 |

### 12.2 Nota: INCITS 359-2012 R2022

La norma ANSI INCITS 359 fue reafirmada en 2022 (R2022) sin cambios sustanciales al
modelo. Es el estándar ANSI vigente para RBAC incluyendo SSD y DSD.

**DSD (Dynamic Separation of Duty)** impone restricciones en tiempo de activación —
un usuario puede tener asignados dos roles conflictivos pero no activarlos simultáneamente.
**SSD (Static Separation of Duty)** impone restricciones en tiempo de asignación.

bAuth debe implementar **ambos**: SSD en asignación (gate pre-persistencia) y DSD en
evaluación (evaluado por el PDP en runtime).

### 12.3 Átomos de referencia

```
d10.delegation.create       — crear delegación (A → B, con reducción AND)
d10.delegation.delete       — revocar delegación
d10.renewal.approve         — renovar delegación con revalidación
d10.renewal.validate        — ¿la delegación sigue vigente?
d10.restrictions.validate   — verificar SoD antes de aprobar delegación
d10.chain.configure         — configurar reglas de sub-delegación en cadena
d10.audit.read              — consultar trazabilidad de cadena de delegación
d10.rich_authorization.configure — [GAP] definir authorization_details para delegación API
d10.rich_authorization.validate  — [GAP] verificar que el scope delegado no excede el propio
```

### 12.4 Gaps D10

| # | Gap | Prioridad |
|---|-----|-----------|
| G-D10-01 | Bloque `chain` (sub-delegación) faltante — INCITS 359 §4.7 + RFC 8693 (Token Exchange) como norma formal | **P1** (era P2) |
| G-D10-02 | Bloque `audit` de delegación faltante — trazabilidad de cadena | P2 |
| G-D10-03 | Bloque `rich_authorization` faltante — RFC 9396 RAR para delegaciones API/M2M programáticas | P2 |

---

## 13. D11 — Auditoría

**Propósito:** WORM — no evalúa, registra TODO con dimensiones completas. Hash-chain
verificable. Post-hoc SIEMPRE, en todas las evaluaciones. Tablas `aud_*`.

**Pipeline:** POST-HOC — siempre ejecutado, incluso si D08/D09 denegaron.

**Estándar principal:** ISO/IEC 27001:2022 A.8.15 (Logging) + A.8.16 (Monitoring) ·
PCI DSS 4.0.1 Req 10 (audit trail mín. 12 meses en línea, 24 meses archivo) ·
NIST SP 800-53 AU-2/AU-3/AU-9 · SOX §802 (7 años papeles de trabajo)

### 13.1 Bloques canónicos

| Bloque | Descripción | Norma | Estado |
|--------|-------------|-------|--------|
| `events` | Captura de eventos de seguridad — autenticación, autorización, errores | ISO 27001 A.8.15 · NIST AU-2 | ✅ |
| `retention` | Política de retención — hot (30–90 d) / warm (12 meses) / cold (7 años) | PCI DSS 4.0.1 Req 10.5.1 · SOX §802 | ✅ |
| `integrity` | Verificación de integridad mediante hash-chain (bauth_44 WORM) | ISO 27001 A.8.15 · NIST AU-9 | ✅ |
| `monitoring` | Monitoreo activo con alertas ante comportamiento anómalo | ISO 27001 A.8.16 · PCI DSS 4.0.1 Req 10.7.3 | ✅ |
| `review` | Revisión periódica formal de logs por auditor designado | ISO 27001 A.8.15 §Implementation · NIST AU-6 | ❌ FALTANTE |
| `export` | Exportación de logs a SIEM externo (Wazuh, Splunk, QRadar) | ISO 27001 A.8.15 · NIST AU-4 | ⚠️ parcial |
| `Zona de Negocios` | Contenedor de aplicaciones del dominio de auditoría — registra sistemas de logging, SIEM y monitoreo con prefijo `zona_audit_*`; acepta solo nodos `politica` con Z0·Identidad. Niveles: audit_level / retention_rule / alert_rule. Definición canónica: A.67 §3–§5.4 | NGAC INCITS 565-2020 §4 · SABSA SCF · ISO/IEC 27001:2022 A.5.15 · XACML 3.0 §5.2 | ❌ definir apps D11 |

### 13.2 Aclaración: retención PCI DSS vs SOX (distintos relojes)

**PCI DSS 4.0.1 Req 10.5.1:** mínimo 12 meses de logs accesibles + 24 meses en archivo.
**SOX §802:** 7 años para papeles de trabajo de auditoría financiera.

Son relojes distintos con propósitos distintos — mezclarlos en un solo bloque `retention`
con un valor fijo único es incorrecto. El átomo debe modular el período según el tipo
de evento auditado (transacción financiera → SOX 7 años; acceso lógico → PCI 12 meses).

### 13.3 Átomos de referencia

```
d11.events.create           — registrar evento de auditoría (WORM)
d11.events.read             — consultar log de eventos
d11.retention.configure     — configurar política de retención por tipo de evento
d11.retention.delete        — purga controlada tras vencimiento de retención
d11.integrity.validate      — verificar hash-chain de log (WORM check)
d11.monitoring.configure    — configurar reglas de alerta activa
d11.monitoring.audit        — revisar alertas generadas
d11.review.approve          — revisión periódica formal por auditor
d11.export.configure        — configurar destino SIEM (Wazuh syslog)
d11.export.execute          — exportar lote de logs a SIEM
```

### 13.4 Gaps D11

| # | Gap | Prioridad |
|---|-----|-----------|
| G-D11-01 | Bloque `review` (revisión formal) faltante — ISO 27001 A.8.15 + NIST AU-6 | P1 |
| G-D11-02 | Retención multi-período no modelada — PCI ≠ SOX, período variable por tipo | P1 |
| G-D11-03 | Bloque `export` incompleto — integración SIEM no declarada formalmente | P2 |

---

## 14. D12 — Blockchain / Anclaje

**Propósito:** Forma A — anclaje Merkle de auditoría (inmutabilidad de log).
Forma B — liquidación Besu QBFT (transacciones blockchain empresarial).
W3C DID para identidades descentralizadas. External-Path.

**Pipeline:** EXTERNAL-PATH — evaluación fuera del core de bAuth.

**Estándar principal:** NIST IR 8202 (Blockchain Technology Overview, 2018 — IR, no SP) ·
W3C DID Core v1.1 (CR marzo 2026) · EIP-725/735 (on-chain identity claims) ·
RFC 6962 (Certificate Transparency / Merkle audit proof) · NIST IR 8301

### 14.1 Bloques canónicos

| Bloque | Descripción | Norma | Estado |
|--------|-------------|-------|--------|
| `anchoring` | Anclaje de hash de batch Merkle en blockchain | RFC 6962 §2 · NIST IR 8202 §3.3 | ✅ |
| `transactions` | Liquidación de transacciones en Besu QBFT | Besu QBFT · EIP-712 (typed data signing) | ✅ |
| `wallet` | Gestión de wallet Ethereum — claves, firma, DID | W3C DID Core v1.1 · EIP-725 | ✅ |
| `did` | Resolución y gestión de DIDs (Decentralized Identifiers) | W3C DID Core v1.1 (CR mar 2026) | ❌ FALTANTE |
| `merkle` | Generación y verificación de pruebas Merkle (Keccak-256) | RFC 6962 §2 · CT ecosystem | ⚠️ implícito en anchoring |
| `consensus` | Monitoreo de consenso QBFT — validadores activos, fork detection | Besu QBFT spec | ❌ FALTANTE |
| `Zona de Negocios` | Contenedor de aplicaciones del dominio blockchain — registra contratos inteligentes y nodos Besu con prefijo `zona_blockchain_*`; acepta solo nodos `politica` con Z0·Identidad. Niveles: chain_id / smart_contract_rule / tx_policy. Definición canónica: A.67 §3–§5.4 | NGAC INCITS 565-2020 §4 · SABSA SCF · ISO/IEC 27001:2022 A.5.15 · XACML 3.0 §5.2 | ❌ definir apps D12 |

### 14.2 Aclaración: peso normativo de NIST IR 8202

NIST IR 8202 es un **Informe Interno** (IR), no una Publicación Especial (SP). Su peso
normativo es **orientativo**, no obligatorio. W3C DID Core v1.1 es una **Candidata a
Recomendación W3C** (CR, marzo 2026) — tampoco es ISO. Ninguno equivale a un estándar
ISO/ANSI exigible en auditoría. Documentarlos con la distinción correcta evita
malentendidos de conformidad.

### 14.3 Átomos de referencia

```
d12.anchoring.emit          — anclar hash de batch Merkle en blockchain
d12.anchoring.validate      — verificar prueba de inclusión Merkle
d12.transactions.execute    — ejecutar transacción Besu QBFT
d12.transactions.validate   — verificar estado de transacción
d12.wallet.configure        — configurar wallet Ethereum para el tenant
d12.wallet.delete           — revocar wallet / rotar claves
d12.did.create              — registrar DID en registro descentralizado
d12.did.resolve             — resolver DID → documento de identidad
d12.merkle.emit             — generar árbol Merkle del batch de auditoría
d12.consensus.audit         — consultar estado de consenso QBFT
```

### 14.4 Gaps D12

| # | Gap | Prioridad |
|---|-----|-----------|
| G-D12-01 | Bloque `did` faltante — W3C DID Core v1.1 (CR mar 2026) | P2 |
| G-D12-02 | Bloque `consensus` (monitoreo QBFT) faltante | P3 |
| G-D12-03 | Peso normativo de NIST IR 8202 y W3C DID mal citado como "estándar" | P1 — doc |

---

## 15. D13 — Firma Digital Externa

**Propósito:** la firma legal como bit — validez jurídica bajo Ley 164 Bolivia. Doble motor
de firma (interno EdDSA / externo ADSIB→AGETIC RSA-SHA256). 36 átomos diseñados (5929–5964).

**Pipeline:** POST-HOC especial — se dispara cuando la operación requiere firma legal.

**Estándar principal:** Ley 164 Bolivia Art. 78 · DS 5519 (disolución ADSIB → AGETIC 2026) ·
RFC 3161 (TSP — Time Stamp Protocol) · ETSI EN 319 422 (perfil TSP) · ETSI EN 319 102-1
(PAdES/XAdES/CAdES)

### 15.1 Bloques canónicos

| Bloque | Descripción | Norma | Estado |
|--------|-------------|-------|--------|
| `signing` | Firma electrónica de documentos — generación y aplicación | Ley 164 Art. 78 · ETSI EN 319 102-1 | ✅ |
| `certification` | Validación de cadena de certificación (CA AGETIC/raíz) | Ley 164 Art. 78 · DS 5519/AGETIC | ✅ |
| `timestamping` | Sello de tiempo RFC 3161 para no repudio temporal | RFC 3161 · ETSI EN 319 422 | ✅ |
| `verification` | Verificación de firma existente (contra cert. AGETIC vigente) | Ley 164 · ETSI EN 319 102-2 | ❌ FALTANTE |
| `revocation` | Consulta OCSP/CRL de certificado de firmante | RFC 6960 (OCSP) · RFC 5280 §5 (CRL) | ❌ FALTANTE |
| `long_term` | Preservación de firma a largo plazo (LTV — Long Term Validation) — eIDAS 2.0 Art. 37 lo hace **obligatorio** para QES | ETSI EN 319 102-2 §7 · eIDAS 2.0 Art. 37 | ❌ FALTANTE |
| `eudi_wallet` | Verificación de credenciales presentadas desde EUDI Wallet — eIDAS 2.0 introduce la EU Digital Identity Wallet como canal oficial | eIDAS 2.0 Reg (EU) 2024/1183 Art. 5a–5c | ❌ FALTANTE |
| `Zona de Negocios` | Contenedor de aplicaciones del dominio de firma digital — registra sistemas de firma electrónica y PKI con prefijo `zona_signature_*`; acepta solo nodos `politica` con Z0·Identidad. Niveles: signature_method / certificate_authority / validity_rule. Definición canónica: A.67 §3–§5.4 | NGAC INCITS 565-2020 §4 · SABSA SCF · ISO/IEC 27001:2022 A.5.15 · Ley 164 Art. 78 | ❌ definir apps D13 |

### 15.2 Alerta: ADSIB disuelta — DS 5519 (enero 2026)

**ADSIB fue disuelta el 14 de enero de 2026** mediante DS 5519. Sus competencias de
certificación digital fueron transferidas a AGETIC. La norma `ADSIB-FD-POLT-015` debe
revisarse para verificar si AGETIC la republicó con nueva numeración. **Citar
`ADSIB-FD-POLT-015` sin verificación en documentos de conformidad es un error** —
puede invalidar la conformidad ante auditoría.

**Acción requerida HITL:** confirmar numeración vigente de la política de certificación
bajo AGETIC antes de commitear átomos D13 a producción.

### 15.3 Átomos de referencia

```
d13.signing.emit            — generar firma digital sobre documento/hash
d13.signing.execute         — aplicar firma a operación que requiere validez jurídica
d13.certification.validate  — verificar cadena de certificación (CA AGETIC)
d13.certification.create    — solicitar certificado digital a AGETIC
d13.timestamping.emit       — solicitar sello de tiempo RFC 3161 a TSA
d13.timestamping.validate   — verificar sello de tiempo
d13.verification.validate   — verificar firma existente en documento
d13.revocation.validate     — consultar OCSP/CRL del firmante
d13.long_term.configure     — configurar política de preservación LTV
d13.eudi_wallet.verify      — [GAP] verificar presentación de credencial desde EUDI Wallet
d13.eudi_wallet.trust       — [GAP] verificar que el wallet emisor está en la Trusted List EU (TLv6)
```

### 15.4 Gaps D13

| # | Gap | Prioridad |
|---|-----|-----------|
| G-D13-01 | Bloque `verification` faltante — verificación de firmas existentes | P1 |
| G-D13-02 | Bloque `revocation` (OCSP/CRL) faltante — RFC 6960 + RFC 5280 | P1 |
| G-D13-03 | Norma ADSIB-FD-POLT-015 caducada — DS 5519 AGETIC: requiere HITL | P1 — HITL |
| G-D13-04 | Bloque `long_term` (LTV) faltante — eIDAS 2.0 Art. 37 lo hace obligatorio para QES | **P1** (era P2) |
| G-D13-05 | Bloque `eudi_wallet` faltante — eIDAS 2.0 Reg (EU) 2024/1183; relevante si SBOS opera con usuarios EU | P3 |
| G-D13-06 | Formato de firma: eIDAS 2.0 migra de XAdES BES a XAdES-BASELINE-B (EN 319 132-1); verificar que `signing` usa el formato correcto | P1 — revisión |
| G-D13-07 | TLv6 (Trusted List v6): nuevo formato obligatorio fin 2025 — `certification.validate` debe soportarlo | P1 — actualización |

---

## 16. D14 — Acceso Privilegiado (PAM)

**Propósito:** ciclo de vida específico de cuentas y sesiones privilegiadas — descubrimiento,
vaulting, JIT/Zero Standing Privilege, brokering de sesión. Distinción de D01 (autorización
runtime) y D10 (delegación entre sujetos). Nuevo dominio confirmado 2026.

**Pipeline:** POLICY-PATH (por definir en implementación).

**Estándar principal:** NIST SP 800-53 R5.2 AC-6 (Least Privilege) · AC-2(6) (Dynamic
Privilege Management) · AC-2(7) (Privileged User Accounts) · NIST SP 800-53 R5.2
(publicado ago 2025) · Gartner Magic Quadrant PAM 2025 (CyberArk, BeyondTrust, Delinea)

### 16.1 Bloques canónicos

| Bloque | Descripción | Norma | Estado |
|--------|-------------|-------|--------|
| `discovery` | Inventario de cuentas/credenciales privilegiadas — reconocimiento continuo | NIST SP 800-53 AC-2(6) | ❌ NUEVO |
| `vaulting` | Almacenamiento y rotación automática de credenciales privilegiadas | NIST SP 800-53 AC-6 · AC-2(7) | ❌ NUEVO |
| `jit` | Acceso efímero Just-In-Time — Zero Standing Privilege, auto-expiración | NIST SP 800-53 AC-6 · AC-2(6) | ❌ NUEVO |
| `brokering` | Mediación y grabación de sesión privilegiada (session proxy) | Patrón industria [I] · NIST AC-6 base | ❌ NUEVO |
| `review` | Revisión periódica de cuentas privilegiadas (trimestral mínimo) | NIST SP 800-53 AC-2(7) · PCI DSS Req 7 | ❌ NUEVO |
| `session_recording` | Grabación y búsqueda de sesiones privilegiadas — distinto del `brokering` (conexión). Las aseguradoras cyber 2025 exigen grabación + búsqueda por comando como condición separada | NIST SP 800-53 R5.2 AU-14 · Gartner MQ PAM 2025 [I] | ❌ NUEVO |
| `Zona de Negocios` | Contenedor de aplicaciones del dominio PAM — registra sistemas de gestión de acceso privilegiado y bóvedas de credenciales con prefijo `zona_pam_*`; acepta solo nodos `politica` con Z0·Identidad. Extiende A.67 §3 para D14 (dominio nuevo post-v1.1). Niveles análogos al patrón A.67 §5.4 | NGAC INCITS 565-2020 §4 · SABSA SCF · ISO/IEC 27001:2022 A.5.15 · NIST SP 800-53 R5.2 AC-6 | ❌ nuevo — definir apps D14 |

### 16.2 Hallazgos de investigación: PAM 2025–2026

**Mercado consolidado:** Gartner Magic Quadrant PAM 2025 identifica CyberArk (adquirida
por Palo Alto Networks en 2025), BeyondTrust y Delinea como líderes. Saviynt gana
reconocimiento por PAM cloud-native.

**Zero Standing Privilege (ZSP):** el mercado 2026 migra activamente de vaulting de
contraseñas estático a ZSP — ningún admin con privilegio permanente, todo bajo demanda
y auto-expirable. Coherente con el hardening de SBOS (usuario `agente-bos` restringido).

**NIST SP 800-53 R5.2 (agosto 2025):** actualización que responde al EO 14306 y refuerza:
- AC-2(7) exige cuenta separada para acceso privilegiado (no la cuenta de uso diario).
- AC-6 refuerza la revisión periódica y la justificación de cada privilegio elevado.
- Cyber insurance 2025: 15–25% de despliegues PAM son por exigencia de aseguradoras
  (MFA, grabación de sesión y JIT como condiciones de cobertura).

### 16.3 Átomos de referencia

```
d14.discovery.read          — inventariar cuentas privilegiadas del tenant
d14.discovery.audit         — auditar inventario de privilegios elevados
d14.vaulting.read           — checkout de credencial privilegiada desde vault
d14.vaulting.configure      — configurar política de rotación automática
d14.vaulting.delete         — rotar forzosamente credencial comprometida
d14.jit.approve             — aprobación de ventana JIT (con duración máxima)
d14.jit.execute             — activar acceso privilegiado efímero
d14.jit.validate            — ¿sigue vigente la ventana JIT?
d14.brokering.execute       — iniciar sesión privilegiada mediada (con grabación)
d14.brokering.audit         — revisar grabación de sesión privilegiada
d14.review.approve          — revisión periódica de cuenta privilegiada
d14.session_recording.configure — configurar política de grabación (qué grabar, retención)
d14.session_recording.read      — consultar grabación de sesión privilegiada
d14.session_recording.search    — buscar comando específico dentro de grabaciones
```

### 16.4 Gaps D14

D14 es completamente nuevo — todos los bloques son gaps.

| # | Gap | Prioridad |
|---|-----|-----------|
| G-D14-01 | Dominio completo sin implementar — 5 bloques nuevos | P1 |
| G-D14-02 | Tabla de grant separada para sujetos privilegiados no decidida (HITL) | P1 — HITL |
| G-D14-03 | Integración con vault de secretos (HashiCorp Vault existente en stack) | P2 |

---

## 17. D15 — Identidad No Humana (NHI)

**Propósito:** ciclo de vida de cuentas de servicio, workloads (contenedores, procesos),
agentes de IA y sus credenciales de máquina. La proporción NHI:humano ya ronda 45:1
(IDSA 2025). Los 12 agentes de la Fábrica SBOS son NHI de tipo `agent`. Nuevo dominio 2026.

**Pipeline:** POLICY-PATH (por definir en implementación).

**Estándar principal:** SPIFFE/SPIRE (CNCF — estándar de facto para workload identity) ·
NIST SP 800-207 §3 (ZTA para workloads) · Gartner Strategic Tech 2025 (NHI como prioridad) ·
[Emergente: sin ISO/NIST formal dedicado a NHI todavía 🔬]

### 17.1 Bloques canónicos

| Bloque | Descripción | Norma | Estado |
|--------|-------------|-------|--------|
| `service_account` | Ciclo de vida de cuentas de servicio y daemons del sistema | Patrón industria [I] · NIST AC-2 aplicado | ❌ NUEVO |
| `workload` | Identidad de carga de trabajo — contenedor, pod, proceso SPIFFE/SVID | SPIFFE/SPIRE (CNCF) · NIST SP 800-207 §3 | ❌ NUEVO |
| `agent` | Identidad de agentes de IA — scope, permisos, ciclo de vida | Emergente 🔬 · AIP arxiv:2603.24775 | ❌ NUEVO |
| `secrets` | Credenciales de máquina — API keys, tokens de servicio, rotación agresiva | Patrón industria [I] · NIST AC-2(2) | ❌ NUEVO |
| `rotation` | Rotación automática de secretos de máquina con período corto (<24h para M2M, <1h para CI/CD) | Patrón industria [I] · Gartner NHI 2025 | ❌ NUEVO |
| `attestation` | Verificación de que el workload/nodo que pide identidad es quien dice ser — corazón del modelo SPIFFE/SPIRE (node attestation + workload attestation); sin este bloque el registro de NHI es vulnerable a impersonation | SPIFFE/SPIRE Attestation Model (CNCF) [I] | ❌ NUEVO |
| `governance` | Gobierno del ciclo de vida NHI — ¿quién aprobó este workload?, ¿sigue siendo necesario?, ¿a qué recursos tiene acceso? Sin governance los NHI se convierten en shadow identities | CSA NHI Governance 2025 [I] · NIST SP 800-53 R5.2 AC-2 aplicado a NHI | ❌ NUEVO |
| `Zona de Negocios` | Contenedor de aplicaciones del dominio NHI — registra workloads, agentes de IA y servicios M2M con prefijo `zona_nhi_*`; acepta solo nodos `politica` con Z0·Identidad. Extiende A.67 §3 para D15 (dominio nuevo post-v1.1). Niveles análogos al patrón A.67 §5.4 | NGAC INCITS 565-2020 §4 · SABSA SCF · ISO/IEC 27001:2022 A.5.15 · SPIFFE/SPIRE (CNCF) | ❌ nuevo — definir apps D15 |

### 17.2 Hallazgos de investigación: NHI 2025–2026

**SPIFFE (Secure Production Identity Framework for Everyone)** es el estándar CNCF
para workload identity — responde "¿cómo prueba un servicio su identidad ante otro
servicio sin password compartido?". SPIRE es la implementación de referencia. Cada
workload registrado obtiene un **SVID** (SPIFFE Verifiable Identity Document) rotado
automáticamente.

**Gartner Strategic Trend 2025:** NHI management fue identificada como tendencia
estratégica top, con énfasis en:
1. Gobernanza de identidades de agentes de IA (explícitamente los 12 agentes de SBOS).
2. Rotación agresiva de secretos (<24h para M2M, <1h para CI/CD).
3. Trazabilidad de quién concedió qué a qué workload.

**Nota de diseño:** distinguir D14 (`vaulting`/`jit` para privilegio humano elevado) de
D15 (`secrets`/`rotation` para credenciales de máquina). El modelo de riesgo es distinto:
un humano puede reportar un compromiso; un agente automatizado puede no detectarlo,
por lo que D15 exige controles más agresivos de rotación y detección de anomalías.

**Sin estándar ISO/NIST formal dedicado a NHI todavía** — es categoría emergente.
Documentar explícitamente como patrón de industria / emergente, nunca forzar una cita
normativa que no existe.

### 17.3 Átomos de referencia

```
d15.service_account.create  — crear cuenta de servicio/daemon
d15.service_account.delete  — eliminar cuenta de servicio (offboarding de daemon)
d15.service_account.audit   — auditar accesos de cuenta de servicio
d15.workload.create         — registrar identidad de workload (SVID SPIFFE)
d15.workload.validate       — verificar identidad del workload antes de conceder acceso
d15.workload.delete         — revocar identidad de workload
d15.agent.create            — registrar agente de IA con scope de permisos
d15.agent.configure         — modificar scope/permisos del agente
d15.agent.audit             — auditar acciones del agente de IA
d15.secrets.validate        — verificar validez de secreto de máquina
d15.secrets.delete          — revocar/rotar secreto de máquina forzosamente
d15.rotation.configure      — configurar política de rotación automática de secretos
d15.rotation.execute        — disparar rotación inmediata de secreto
d15.attestation.validate    — verificar attestation del nodo/workload antes de emitir SVID
d15.attestation.configure   — configurar métodos de attestation permitidos (TPM, K8s, AWS)
d15.governance.review       — revisar inventario de NHIs y su justificación de negocio
d15.governance.approve      — aprobar creación de nueva NHI (proceso de solicitud formal)
d15.governance.offboard     — ciclo de baja de NHI incluyendo revocación de secretos
```

### 17.4 Gaps D15

D15 es completamente nuevo — todos los bloques son gaps.

| # | Gap | Prioridad |
|---|-----|-----------|
| G-D15-01 | Dominio completo sin implementar — **7 bloques** (se añaden `attestation` y `governance`) | P1 |
| G-D15-02 | Decisión sobre subject_type (humano/máquina/servicio/agente) en grant | P1 — HITL |
| G-D15-03 | Integración SPIFFE/SPIRE no evaluada para workload identity + `attestation` | P2 |
| G-D15-04 | Estándar de identidad de agentes de IA emergente — sin norma ISO/NIST formal todavía | 🔬 |
| G-D15-05 | `governance` NHI sin proceso de solicitud formal — shadow identities crecen sin control (CSA NHI 2025) | P1 |

---

## 18. D98 — Registro Estructural

**Propósito:** registro estructural del árbol de átomos — metadatos del catálogo de
identidad, no plano de evaluación. Los nodos D98 son el "esqueleto" que da forma al
árbol antes de que los datos de dominio lo pueblen.

**Pipeline:** Pre-condición estructural (no genera bit propio, no evalúa en runtime).

**Estándar principal:** SBOS interno (norma propia) · ISO/IEC 24760-1:2019 §5 (vocabulario
de identity management) · SCIM 2.0 RFC 7642 (esquema de atributos)

### 18.1 Bloques canónicos

| Bloque | Descripción | Norma | Estado |
|--------|-------------|-------|--------|
| `schema` | Definición del esquema de atributos del catálogo | ISO 24760-1:2019 §5 · SCIM RFC 7643 | ✅ |
| `catalog` | Registro del catálogo de átomos disponibles | NIST SP 800-162 §4 (attr catalog) | ✅ |
| `versioning` | Control de versiones del árbol estructural | SBOS interno · semver | ⚠️ implícito |

---

## 19. D99 — Administrativo Global

**Propósito:** baseline administrativo global — la configuración que garantiza a todos
los demás dominios. No tiene bits ni roles propios; 447 nodos distribuidos a los 5 daemons
vía `bauth.config.global_get`. Cambia solo por HITL. Fuera del BitMask.

**Pipeline:** No evalúa — distribuido como configuración global.

**Estándar principal:** NIST SP 800-53 SA-22 (gestión de componentes no soportados) ·
ISO/IEC 27001:2022 A.5.20 (gestión de suministradores) · NIST CA-6 (authorization)

### 19.1 Bloques canónicos

| Bloque | Descripción | Norma | Estado |
|--------|-------------|-------|--------|
| `users` | Gestión global de usuarios del sistema (SU, M2M) | NIST AC-2 · ISO 27001 A.5.18 | ✅ |
| `notifications` | Configuración de notificaciones globales → bNotify | SBOS interno | ✅ |
| `exceptions` | Override HITL — excepciones aprobadas por control | NIST CA-6 · ISO 27001 A.5.30 | ✅ |
| `cryptography` | Parámetros globales de criptografía — algoritmos, tamaños de clave, agotamiento por algoritmo | NIST SP 800-57 Part 1 Rev.5 (key management) | ⚠️ implícito → debe ser formal |
| `compliance` | Mapa de conformidad — qué normas aplican al tenant (Declaración de Aplicabilidad ISO 27001) | ISO/IEC 27001:2022 §6.1 | ❌ FALTANTE |
| `supply_chain` | Gestión de riesgos de cadena de suministro de software — SBOM, componentes soportados, integridad | NIST SP 800-53 R5.2 SA-22 + SR family (agosto 2025) | ❌ FALTANTE |

---

## 20. Matriz de completitud normativa (v1.6.0)

> Conteo actualizado desde v1.5.0: bloque `Zona de Negocios` sumado (+1) a cada D01–D15.
> D98/D99: `Zona de Negocios` requerida por A.67 §3 pero no incorporada en §18/§19 — pendiente.

| Dominio | Nombre | Bloques totales | Gaps pendientes | Norma principal | Estado |
|---------|--------|:--------------:|:---------------:|----------------|:------:|
| D00 | Identidad Organizacional | 11 | 4 (`consent`, `vc`, `fal`, DDL proofing) | ISO 24760-2:2025 · SP 800-63A-4 | 🟡 |
| D01 | Acceso Lógico | 9 | 3 (`certification`, `session`⚠️, `dynamic_policy`) | INCITS 359 R2022 · CAEP 1.0 Final | 🔴 |
| D02 | Acceso Físico | 8 | 4 (`visitors`, `emergency`, `mustering`, `Zona de Negocios`) | IEC 60839-11-5:2020 · OSDP v2.2.2 | 🟡 |
| D03 | Financiero | 9 | 5 (`reporting`, `fraud`P0, `recon.`, `OB`, `Zona de Negocios`) | PCI DSS 4.0.1 · SOX §404 · COSO | 🔴 |
| D04 | Temporal | 6 | 3 (`schedules`, `exceptions`, `Zona de Negocios`) | GTRBAC (Bertino et al., IEEE TDKE 2005) · RFC 5545 | 🟡 |
| D05 | Biométrico | 7 | 4 (`quality`P0, `revocation`, `id`, `Zona de Negocios`) | ISO/IEC 30107-3:2023 · ISO 29794-1:2024 | 🔴 |
| D06 | Geoespacial | 6 | 3 (`residency`, `fleet`, `Zona de Negocios`) | OGC GeoFence v1.0 · SP 800-207 | 🟡 |
| D07 | Red | 8 | 5 (`posture`, `segment.`, `insp.`, `prop.`, `Zona de Negocios`) | SP 800-207 + 207A · RFC 9449 (DPoP) | 🔴 |
| D08 | Contexto / Sesión | 8 | 3 (`assurance`, `itdr`, `Zona de Negocios`) | CAEP 1.0 Final (sep 2025) · SBOS-049 | 🟡 |
| D09 | Credenciales | 10 | 4 (`passkey`P0, `recovery`⚠️, `bind.`⚠️, `introspection`, `Zona de Negocios`) | SP 800-63B-4 Final (jul 2025) · FIDO2 | 🟡 |
| D10 | Delegación | 7 | 4 (`chain`→P1, `audit`, `rich_auth`, `Zona de Negocios`) | INCITS 359 R2022 · RFC 8693 | 🟡 |
| D11 | Auditoría | 7 | 2 (`review`, `Zona de Negocios`) | ISO 27001 A.8.15 · PCI DSS 4.0.1 Req 10 | 🟡 |
| D12 | Blockchain / Anclaje | 7 | 3 (`did`→P1, `consensus`, `Zona de Negocios`) | W3C VCDM 2.0 (Rec) · W3C DID v1.1 (CR) | 🟡 |
| D13 | Firma Digital Externa | 8 | 5 (`verif.`, `revoc.`, `long_term`→P1, `EUDI`, `Zona de Negocios`) | Ley 164 · ETSI EN 319 102 · DS 5519/AGETIC | 🔴 HITL |
| D14 | Acceso Privilegiado (PAM) | 7 | 7 (dominio nuevo — todos los bloques) | SP 800-53 R5.2 AC-6/AC-2(7) · Gartner PAM 2025 [I] | ❌ |
| D15 | Identidad No Humana (NHI) | 8 | 8 (dominio nuevo — todos los bloques) | SPIFFE/SPIRE (CNCF) · CSA NHI 2025 [I] | ❌ 🔬 |
| D98 | Registro Estructural | 3 | 0 (+`Zona de Negocios` pendiente) | SBOS interno · ISO 24760-1:2019 | ✅ |
| D99 | Administrativo Global | 6 | 3 (`compliance`, `crypto` formal, `supply_chain`) (+`Zona de Negocios` pendiente) | SP 800-53 R5.2 SA-22 · ISO 27001:2022 | 🟡 |

**Resumen v1.6.0:** 1 dominio ✅ (D98) · 10 dominios 🟡 parciales · 5 dominios 🔴 críticos ·
2 dominios ❌ nuevos · **143 bloques totales** (128 pre-v1.5.0 + 15 `Zona de Negocios` D01–D15) ·
**Gaps P0:** `passkey`(D09) · `quality`(D05) · `identity_proofing DDL`(D00) · `fraud`(D03)

---

## 21. Gaps críticos y recomendaciones

### 21.1 P1 — Decisiones urgentes (bloquean conformidad normativa)

| Gap ID | Dominio | Problema | Acción |
|--------|---------|---------|--------|
| G-D13-03 | D13 | ADSIB disuelta (DS 5519) — norma `ADSIB-FD-POLT-015` puede no estar vigente | HITL: confirmar política AGETIC vigente antes de producción |
| G-D14-02 | D14 | Decisión sobre tabla grant separada para sujetos privilegiados | HITL: ¿columna `subject_type` en `privilege_atom_grant`? |
| G-D15-02 | D15 | Decisión sobre modelado de agentes de IA como sujetos | HITL: ¿`d15.agent` o extensión del modelo de usuario? |
| G-D03-01 | D03 | Bloque `reporting` faltante — SOX §302 obligatorio | Diseñar átomos de reporting financiero |
| G-D01-01 | D01 | IGA (`certification`) faltante — Gartner + NIST AC-2(7) | Agregar bloque `certification` a D01 |
| G-D09-01 | D09 | Passkeys no modeladas como bloque propio — SP 800-63B-4 §4.2 base AAL2 | Agregar bloque `passkey` a D09 |
| G-D08-01 | D08 | `assurance` faltante — CAEP `Assurance Level Change` | Agregar bloque `assurance` a D08 |

### 21.2 P2 — Gaps normativos importantes

| Gap ID | Dominio | Problema | Acción |
|--------|---------|---------|--------|
| G-D05-01 | D05 | `quality` biométrico faltante — ISO 29794-1:2024 | Agregar bloque a D05 |
| G-D05-02 | D05 | `revocation` de template biométrico faltante | Agregar bloque a D05 |
| G-D07-01 | D07 | `posture` de red faltante — SP 800-207 §3.2 | Agregar bloque a D07 |
| G-D11-01 | D11 | `review` periódica formal faltante — ISO 27001 A.8.15 + AU-6 | Agregar bloque a D11 |
| G-D11-02 | D11 | Retención multi-período no modelada — PCI ≠ SOX | Rediseñar átomo `retention` con tipo_evento |
| G-D02-01 | D02 | `visitors` (acceso temporal terceros) faltante | Agregar bloque a D02 |
| G-D12-03 | D12 | NIST IR 8202 y W3C DID citados con peso normativo incorrecto | Corregir en documentación |

### 21.3 P3 — Mejoras futuras

| Gap ID | Dominio | Descripción |
|--------|---------|-------------|
| G-D00-03 | D00 | Verifiable Credentials / mDL — roadmap SSI |
| G-D06-02 | D06 | Bloque `fleet` — flotas y drones con identidad geográfica |
| G-D15-04 | D15 | Estándar de identidad de agentes de IA — seguir especificación AIP |
| G-D12-01 | D12 | DID Core v1.1 (CR) — implementar cuando llegue a Recomendación W3C |

### 21.4 Aclaraciones de peso normativo (correcciones documentales)

Los siguientes ítems están citados con un peso normativo mayor al real en la documentación
existente. Corregir antes de entregar a auditoría:

| Citado como | Peso real | Corrección |
|-------------|-----------|-----------|
| `NIST IR 8202` como "estándar" | IR (Informe Interno) — orientativo, no obligatorio | Citar como "NIST IR 8202 (referencia técnica)" |
| `W3C DID Core v1.1` como "estándar" | Candidate Recommendation (CR, mar 2026) — no finalizado | Citar como "W3C DID Core v1.1 (CR)" |
| `ADSIB-FD-POLT-015` | Posiblemente derogada por DS 5519 (ene 2026) | HITL: verificar con AGETIC |
| `GTRBAC` como "norma" | Marco académico (IEEE TDKE 2005) — no es estándar ISO/NIST | Citar como "GTRBAC (Bertino et al., IEEE TDKE 2005)" |
| `velocity` en D06 como norma | Patrón UEBA de industria — sin número de norma | Citar como "patrón de industria" |

---

## 22. Tabla del RolTemplate — Bloques canónicos consolidados por dominio

Referencia rápida de todos los bloques canónicos confirmados por la investigación §2–§19.
Orden canónico de dominios: D00 → D15 → D98 → D99 (dos dígitos obligatorios).
`Zona de Negocios` incorporada en D01–D15 (A.67 v1.2.0); requerida en D98/D99 pero pendiente (†).

**Leyenda:** ✅ presente · ⚠️ parcial · ❌ faltante · 🔬 emergente

| Dominio | Nombre | Bloques canónicos | N° | ❌/⚠️ | Norma principal |
|:-------:|--------|-------------------|:--:|:-----:|-----------------|
| **D00** | Identidad Organizacional | `rol_esquema`✅ · `rol_entidad`✅ · `usuario_esquema`✅ · `usuario_entidad`✅ · `atributos`✅ · `proofing`✅ · `consentimiento`❌ · `verifiable_credential`❌ · `fal`❌ | 9 | 3❌ | ISO 24760-2:2025 · SP 800-63A-4 |
| **D01** | Acceso Lógico | `authorization`✅ · `roles`✅ · `zones`✅ · `fields`✅ · `contracts`✅ · `session`⚠️ · `certification`❌ · `dynamic_policy`❌ · `Zona de Negocios`✅ | 9 | 2❌ 1⚠️ | INCITS 359 R2022 · CAEP 1.0 Final |
| **D02** | Acceso Físico | `facilities`✅ · `readers`✅ · `presence`✅ · `antipassback`⚠️ · `visitors`❌ · `emergency`❌ · `mustering`❌ · `Zona de Negocios`❌ | 8 | 4❌ 1⚠️ | IEC 60839-11-5:2020 · OSDP v2.2.2 |
| **D03** | Financiero | `limits`✅ · `approvals`✅ · `segregation`✅ · `billing`✅ · `reporting`❌ · `fraud`❌ · `reconciliation`❌ · `open_banking`❌ · `Zona de Negocios`❌ | 9 | 5❌ | PCI DSS 4.0.1 · SOX §404 · COSO |
| **D04** | Temporal | `windows`✅ · `periods`✅ · `calendar`✅ · `schedules`❌ · `exceptions`❌ · `Zona de Negocios`❌ | 6 | 3❌ | GTRBAC (Bertino et al., IEEE TDKE 2005) · RFC 5545 |
| **D05** | Biométrico | `enrollment`✅ · `verification`✅ · `liveness`✅ · `identification`❌ · `quality`❌ · `revocation`❌ · `Zona de Negocios`❌ | 7 | 4❌ | ISO/IEC 30107-3:2023 · ISO 29794-1:2024 |
| **D06** | Geoespacial | `geofencing`✅ · `location`✅ · `velocity`✅ · `residency`❌ · `fleet`❌ · `Zona de Negocios`❌ | 6 | 3❌ | OGC GeoFence v1.0 · SP 800-207 |
| **D07** | Red | `connection`✅ · `tokens`✅ · `rate`✅ · `posture`❌ · `segmentation`❌ · `inspection`❌ · `propagation`❌ · `Zona de Negocios`❌ | 8 | 5❌ | SP 800-207 + 207A · RFC 9449 (DPoP) |
| **D08** | Contexto / Sesión | `session`✅ · `risk`✅ · `device`✅ · `emergency`✅ · `assurance`❌ · `itdr`❌ · `Zona de Negocios`❌ | 7 | 3❌ | CAEP 1.0 Final (sep 2025) · SBOS-049 |
| **D09** | Credenciales | `password`✅ · `mfa`✅ · `certificates`✅ · `tokens`✅ · `revocation`✅ · `recovery`⚠️ · `binding`⚠️ · `passkey`❌ · `introspection`❌ · `Zona de Negocios`❌ | 10 | 2❌ 2⚠️ | SP 800-63B-4 Final (jul 2025) · FIDO2 |
| **D10** | Delegación | `delegation`✅ · `renewal`✅ · `restrictions`✅ · `chain`❌ · `audit`❌ · `rich_authorization`❌ · `Zona de Negocios`❌ | 7 | 4❌ | INCITS 359 R2022 · RFC 8693 |
| **D11** | Auditoría | `events`✅ · `retention`✅ · `integrity`✅ · `monitoring`✅ · `export`⚠️ · `review`❌ · `Zona de Negocios`❌ | 7 | 1❌ 1⚠️ | ISO 27001 A.8.15 · PCI DSS 4.0.1 Req 10 |
| **D12** | Blockchain / Anclaje | `anchoring`✅ · `transactions`✅ · `wallet`✅ · `merkle`⚠️ · `did`❌ · `consensus`❌ · `Zona de Negocios`❌ | 7 | 2❌ 1⚠️ | W3C VCDM 2.0 (Rec) · W3C DID v1.1 (CR) |
| **D13** | Firma Digital Externa | `signing`✅ · `certification`✅ · `timestamping`✅ · `verification`❌ · `revocation`❌ · `long_term`❌ · `eudi_wallet`❌ · `Zona de Negocios`❌ | 8 | 5❌ | Ley 164 · ETSI EN 319 102 · DS 5519/AGETIC |
| **D14** | Acceso Privilegiado (PAM) | `discovery`❌ · `vaulting`❌ · `jit`❌ · `brokering`❌ · `review`❌ · `session_recording`❌ · `Zona de Negocios`❌ | 7 | 7❌ | SP 800-53 R5.2 AC-6/AC-2(7) · Gartner PAM 2025 [I] |
| **D15** | Identidad No Humana (NHI) | `service_account`❌ · `workload`❌ · `agent`❌🔬 · `secrets`❌ · `rotation`❌ · `attestation`❌ · `governance`❌ · `Zona de Negocios`❌ | 8 | 8❌🔬 | SPIFFE/SPIRE (CNCF) · CSA NHI 2025 [I] |
| **D98** | Registro Estructural | `schema`✅ · `catalog`✅ · `versioning`⚠️ · `Zona de Negocios`⚠️† | 4 | 1⚠️ | SBOS interno · ISO 24760-1:2019 · SCIM RFC 7643 |
| **D99** | Administrativo Global | `users`✅ · `notifications`✅ · `exceptions`✅ · `cryptography`⚠️ · `compliance`❌ · `supply_chain`❌ · `Zona de Negocios`⚠️† | 7 | 2❌ 2⚠️ | SP 800-53 R5.2 SA-22 · ISO 27001:2022 |

† `Zona de Negocios` declarada como requerida en A.67 v1.2.0 §3 para D98 (`zona_diag_*`) y D99 (`zona_admin_*`).
No incorporada en las tablas §18.1 y §19.1 de este documento — pendiente en próxima revisión.

### Totales v1.6.0

| Indicador | Valor |
|-----------|-------|
| Dominios activos | 18 (D00–D15 + D98 + D99) |
| Bloques declarados | 143 (128 pre-v1.5.0 + 15 `Zona de Negocios` D01–D15) |
| Zona de Negocios incorporada | D01–D15 ✅ (A.67 v1.2.0 · NGAC INCITS 565-2020 §4) |
| Zona de Negocios pendiente | D98 · D99 |
| Dominios sin implementar | D14, D15 (❌ completo) |
| Gaps P0 | `passkey`(D09) · `quality`(D05) · `identity_proofing DDL`(D00) · `fraud`(D03) |

---

## Historial del documento

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.6.0 | 2026-07-23 | **§22 creado:** Tabla del RolTemplate — referencia consolidada de todos los bloques canónicos por dominio (D00→D15→D98→D99, orden y formato de dos dígitos). **§20 actualizado** a v1.6.0: conteos incrementados +1 (Zona de Negocios) para D01–D15; total pasa de 128 a 143 bloques; D98/D99 notan pendiente ZN. **TOC** ampliado con entrada §22. |
| 1.5.0 | 2026-07-23 | Bloque `Zona de Negocios` añadido a todos los dominios D01–D15: contenedor de aplicaciones por dominio basado en A.67 §3 (NGAC INCITS 565-2020 · SABSA SCF · ISO/IEC 27001:2022 A.5.15). Prefijos canónicos: `zona_logical_*`(D01) · `zona_fisica_*`(D02) · `zona_financial_*`(D03) · `zona_temporal_*`(D04) · `zona_biometric_*`(D05) · `zona_geo_*`(D06) · `zona_network_*`(D07) · `zona_context_*`(D08) · `zona_credential_*`(D09) · `zona_delegation_*`(D10) · `zona_audit_*`(D11) · `zona_blockchain_*`(D12) · `zona_signature_*`(D13) · `zona_pam_*`(D14) · `zona_nhi_*`(D15). D14/D15 extienden A.67 (dominios nuevos post-v1.1). |
| 1.2.0 | 2026-07-23 | D00 §2.1: tabla de bloques reestructurada con columna Capa (GENERAL / PARTICULAR) conforme a A.64 §6 "Separación GENERAL / PARTICULAR — principio rector". Bloque `entidad` separado en `esquema` (GENERAL — el molde de campos canónicos: id, parent_id, type_id, name, metadata, audit — aplica a TODAS las entidades) + `entidad` (PARTICULAR — los valores concretos de UNA entidad específica: org_unit_id, sector_code, accountability_chain). Átomos de referencia reorganizados en dos secciones: capa general + capa particular. |
| 1.1.0 | 2026-07-23 | Normalización de códigos D01–D09 (formato dos dígitos en todo el documento). Reescritura completa de D00: los bloques `identity`+`organization` reemplazados por `entidad`+`atributos` (alineados con A.01 §17.3-D0 + A.01 §22 + A.02 B01+B03 §19.2-U1). Clarificación arquitectónica: D00 es pre-condición estructural sin bits propios; sus átomos los evalúa el Motor de Identidad (2.15), no el BitMask. Diagrama de pipeline añadido. Patrón de átomos `d00.{bloque}.{atributo?}.{verbo}` con referencia al patrón legacy `org.gNN.d00.<attr>` de seeds. Nuevo gap G-D00-02 (identity_proofing sin materializar en DDL). |
| 1.0.0 | 2026-07-23 | Versión inicial. Investigación normativa completa de los 18 dominios (D00–D15, D98, D99): bloques canónicos verificados contra normas primarias, hallazgos de novedades normativas 2024–2026 (SP 800-63-4 final ago 2025, NIST SP 800-53 R5.2 ago 2025, CAEP 1.0 final 2025, SIA OSDP v2.2.2 oct 2024, DS 5519 AGETIC ene 2026, SPIFFE/SPIRE CNCF, W3C DID Core v1.1 CR mar 2026), identificación de 35+ gaps por dominio con prioridad P1/P2/P3, árbol de átomos de referencia con formato canónico `dNN.bloque.verbo`, matriz de completitud normativa de los 18 dominios, aclaraciones de peso normativo (IR vs SP vs CR vs patrón de industria), y recomendaciones de decisiones HITL pendientes (AGETIC, subject_type, tabla grant NHI). |
