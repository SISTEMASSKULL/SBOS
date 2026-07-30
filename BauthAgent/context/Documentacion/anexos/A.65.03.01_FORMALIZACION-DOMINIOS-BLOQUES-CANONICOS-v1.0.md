# A.65.03.01 — Formalización Canónica: Dominios y Bloques de bAuth

**Versión:** 1.0.0 · **Fecha:** 2026-07-28
**Tipo:** Formalización canónica (derivado de A.65.03 + BD verificada)
**SSOT de bloques:** `bauth.idn_roles_template` — VPS SBOSDB (2026-07-28)
**Total bloques verificados:** 134 nodos tipo `bloque` · 18 dominios · depth=2
**Fuente de investigación:** A.65.03 v1.6.0 + normas primarias 2024–2026

> **Distinción respecto a A.65.03:** A.65.03 es la **investigación** (qué debería existir según
> normas). Este documento es la **formalización** (qué existe en la BD + especificación normativa
> completa). La BD es el SSOT de qué bloques hay; este documento les da su especificación
> definitiva. Los bloques marcados como ❌ en A.65.03 que ya existen en BD se formalizan aquí
> sin distinción — existen y están especificados.

---

## Tabla de contenidos

1. [Metodología](#1-metodología)
2. [D00 — Identidad Organizacional](#2-d00--identidad-organizacional-9-bloques)
3. [D01 — Control de Acceso Lógico](#3-d01--control-de-acceso-lógico-9-bloques)
4. [D02 — Control de Acceso Físico](#4-d02--control-de-acceso-físico-8-bloques)
5. [D03 — Controles Financieros](#5-d03--controles-financieros-9-bloques)
6. [D04 — Acceso Temporal](#6-d04--acceso-temporal-6-bloques)
7. [D05 — Autenticación Biométrica](#7-d05--autenticación-biométrica-7-bloques)
8. [D06 — Acceso Geoespacial](#8-d06--acceso-geoespacial-6-bloques)
9. [D07 — Seguridad de Red](#9-d07--seguridad-de-red-8-bloques)
10. [D08 — Contexto / Sesión](#10-d08--contexto--sesión-7-bloques)
11. [D09 — Gestión de Credenciales](#11-d09--gestión-de-credenciales-10-bloques)
12. [D10 — Delegación e Impersonación](#12-d10--delegación-e-impersonación-7-bloques)
13. [D11 — Auditoría y Cumplimiento](#13-d11--auditoría-y-cumplimiento-7-bloques)
14. [D12 — Anclaje Blockchain](#14-d12--anclaje-blockchain-7-bloques)
15. [D13 — Firma Digital Externa](#15-d13--firma-digital-externa-8-bloques)
16. [D14 — Gestión de Acceso Privilegiado (PAM)](#16-d14--gestión-de-acceso-privilegiado-pam-7-bloques)
17. [D15 — Identidad No Humana (NHI)](#17-d15--identidad-no-humana-nhi-8-bloques)
18. [D98 — Registro Estructural](#18-d98--registro-estructural-4-bloques)
19. [D99 — Administración Global](#19-d99--administración-global-7-bloques)
20. [Discrepancias resueltas](#20-discrepancias-resueltas)
21. [Resumen de bloques por dominio](#21-resumen-de-bloques-por-dominio)
22. [Estado de implementación global](#22-estado-de-implementación-global)

---

## 1. Metodología

### 1.1 SSOT y fuentes

| Fuente | Rol | Autoridad |
|--------|-----|-----------|
| `bauth.idn_roles_template` (SBOSDB) | Qué bloques existen — lista canónica | **SSOT** |
| A.65.03 v1.6.0 | Investigación normativa — descripción y átomos | Referencia |
| Normas primarias 2024–2026 | Actualización y robustecimiento | Normativa |

### 1.2 Convención de slugs canónicos

El slug canónico de un bloque es el `clave` registrado en `idn_roles_template`. Los átomos
siguen el patrón `dNN.<slug>.<verbo>`.

### 1.3 Estado de implementación por bloque

Todos los 134 bloques existen a **depth=2** en la BD. Ninguno tiene hijos (átomos/políticas
a depth≥3). El trabajo pendiente es poblar los átomos — no crear los bloques.

| Nivel | Significado |
|-------|-------------|
| ⬜ | Bloque existe (depth=2), sin átomos |
| 🔨 | Átomos en diseño |
| ✅ | Átomos insertados y verificados |

Estado actual de todos los bloques: **⬜** (estructura presente, átomos pendientes).

---

## 2. D00 — Identidad Organizacional (9 bloques)

**Propósito:** Define QUÉ ES la entidad y QUÉ PUEDE LEERSE o ESCRIBIRSE de sus atributos.
Árbol organizacional (tenant → bdomain → bsubdomain → pos → actor) y catálogo de atributos.
Pre-condición estructural de todos los dominios — sus átomos los evalúa el Motor de Identidad,
no el BitMask. **Sin bits propios en el BitMask 64-bit.**

**Pipeline:** PRE-CONDICIÓN — evaluado por el Motor de Identidad (manual 2.15), no FastPath.

**Normas principales:** ISO/IEC 24760-2:2025 · NIST SP 800-63A-4 (final agosto 2024) ·
SCIM 2.0 RFC 7643 · GDPR Art. 6-7 · W3C VC Data Model 2.0 (Rec mayo 2025) ·
NIST SP 800-63-4 §5 (FAL — Federation Assurance Level)

**Investigación 2025-2026:** NIST SP 800-63A-4 (agosto 2024) introduce IAL como dimensión
modular independiente. W3C VC Data Model 2.0 es Recomendación oficial desde mayo 2025 —
las Verifiable Credentials dejan de ser experimentales. eIDAS 2.0 (Reglamento UE 2024/1183)
adopta VCDM 2.0 para la EUDI Wallet. ISO/IEC 24760-2:2025 actualiza la arquitectura de
referencia de identidad: separa explícitamente el esquema (molde general) de la entidad
(valores particulares de una instancia) — base del modelo General/Particular de bAuth.

| Código | Slug canónico | Nombre BD | Descripción | Norma principal |
|--------|--------------|-----------|-------------|-----------------|
| B01 | `rol_esquema` | Role Schema | Estructura canónica que TODOS los roles deben cumplir: `id`, `parent_id`, `type_id`, `hierarchy_level`, `name{}`, `metadata{}`, `audit{}`, `digital_signature{}`. El MOLDE del RolTemplate — define campos, no valores de un rol concreto | ISO 24760-2:2025 §5 · SCIM RFC 7643 §4.1 · ANSI INCITS 359-2004 §4.1 |
| B02 | `rol_entidad` | Role Entity | Valores concretos de UN rol específico: `org_unit_id`, `sector_code`, `tenant_id`, `accountability_chain`, vigencia, aprobadores. Distingue a VENDEDOR_SENIOR de GERENTE_REGIONAL | ISO 24760-2:2025 §6 · SCIM RFC 7643 §4.3 Enterprise |
| B03 | `usuario_esquema` | User Schema | Estructura canónica que TODOS los usuarios deben cumplir: `uuid`, `username`, `tenant_id`, `account_type`, `version`, `status`, campos SCIM Core B01 + Enterprise B03. El MOLDE del UserTemplate | ISO 24760-2:2025 §5 · SCIM RFC 7643 §4.1+4.3 |
| B04 | `usuario_entidad` | User Entity | Valores concretos de UN usuario: su uuid, username, department, manager, reporting_line, metadatos de posición. Distingue a Juan Pérez de María López | ISO 24760-2:2025 §6 · SCIM RFC 7643 §4.3 Enterprise |
| B05 | `atributos` | Extended Attributes | Atributos extendidos de UNA entidad (`idn_identity_attribute`): ¿quién puede leer/escribir qué atributo de qué entidad? Motor de Identidad (2.15) evalúa. Patrón legacy: `org.gNN.d00.<attr>` | NIST SP 800-162 §4 · ISO 24760-2:2025 §6.3 · SCIM RFC 7643 §7 |
| B06 | `proofing` | Identity Proofing | IAL alcanzado por UN usuario: tipo (auto/remoto/presencial), evidencia FAIR+STRONG+SUPERIOR, fecha, re-proofing programado. Log WORM por evento. Aplica a personas | NIST SP 800-63A-4 §4–6 (final ago 2024) · ISO/IEC 29115:2013 |
| B07 | `consentimiento` | Privacy Consent | Consentimiento de UN usuario para procesamiento de SUS atributos: versión de política, fecha, canal, derecho de supresión. Obligatorio en IAL2+. GDPR Art. 6 distingue 6 bases legales — consentimiento es una | GDPR Art. 6-7 · ISO/IEC 29184:2020 · NIST SP 800-63-4 §10 |
| B08 | `verifiable_credential` | W3C Verifiable Credential | Emisión y verificación de Verifiable Credentials sobre atributos del sujeto. W3C VCDM 2.0 es Recomendación desde mayo 2025. eIDAS 2.0 lo adopta para EUDI Wallet | W3C VC Data Model 2.0 (Rec mayo 2025) · eIDAS 2.0 Art. 45 · ISO/IEC 18013-5:2021 |
| B09 | `fal` | Federation Assurance Level | FAL1/FAL2/FAL3 — nivel de confianza de las aserciones de federación cuando bAuth actúa como IdP OIDC/SAML. NIST SP 800-63-4 lo introduce como 3ª dimensión independiente (separada de IAL y AAL) | NIST SP 800-63-4 §5 · OpenID Connect Core §3.3 · SAML 2.0 |

**Átomos de referencia (patrón `d00.<slug>.<verbo>`):**
```
d00.rol_esquema.read            d00.rol_esquema.configure
d00.rol_entidad.create          d00.rol_entidad.read
d00.rol_entidad.configure       d00.rol_entidad.delete
d00.usuario_esquema.read        d00.usuario_esquema.configure
d00.usuario_entidad.create      d00.usuario_entidad.read
d00.usuario_entidad.configure   d00.usuario_entidad.delete
d00.atributos.read              d00.atributos.write         d00.atributos.validate
d00.proofing.validate           d00.proofing.approve        d00.proofing.configure
d00.consentimiento.write        d00.consentimiento.read     d00.consentimiento.delete
d00.verifiable_credential.issue d00.verifiable_credential.verify
d00.fal.configure               d00.fal.validate
```

---

## 3. D01 — Control de Acceso Lógico (9 bloques)

**Propósito:** Autenticación y autorización digital — sesiones, tokens, step-up, MFA, zonas
de aplicación, campos de datos, contratos de acceso, recertificación IGA. FastPath puro
(<0.5 ns, bit directo). 221 roles (SU a BIZ_N5, LoA 3→1 según tier).

**Pipeline:** FAST-PATH — primer plano evaluado tras las pre-condiciones D00/D08/D09.

**Normas principales:** ANSI INCITS 359:2012 R2022 (RBAC) · NIST SP 800-63B-4 (AAL1–3) ·
XACML 3.0 §7 · RFC 9470 (Step-Up) · OpenID CAEP 1.0 Final (sep 2025) · NIST SP 800-162 (ABAC)

**Investigación 2025-2026:** CAEP 1.0 Final (septiembre 2025) estandariza `session-revoked`
y `token-claims-change` como tipos de evento formales — el bloque `session` debe implementarlos.
NIST CSF 2.0 PR.AA-04 exige verificación dinámica de identity assertions — base normativa del
bloque `dynamic_policy`. Gartner IGA Market Guide 2025-2026 establece que los programas IGA
fallan cuando no capturan entitlement sprawl real — el bloque `certification` implementa
NIST AC-2(7) como respuesta directa. RFC 9396 (RAR) formaliza `authorization_details` como
estructura estándar para políticas ABAC granulares.

| Código | Slug canónico | Nombre BD | Descripción | Norma principal |
|--------|--------------|-----------|-------------|-----------------|
| B01 | `authorization` | PDP Policy Evaluation | Evaluación PDP — ¿puede el sujeto hacer esta acción en este recurso ahora? Motor XACML/ABAC. Responde Permit/Deny/Indeterminate/NotApplicable | XACML 3.0 §7 · NIST SP 800-53 R5.2 AC-3 · INCITS 359 §3 |
| B02 | `roles` | Role Lifecycle Management | Gestión del ciclo de vida de roles RBAC: DEFINIDO→ACTIVO→SUSPENDIDO→RETIRADO. Asignación, delegación, herencia DAG. 368 roles en 7 tiers | INCITS 359 §4 · NIST AC-2 · ISO 27001:2022 A.5.15 |
| B03 | `zones` | Application Zone Enforcement | Control de acceso a zonas de aplicación (record/field/button/data). Modelo NGAC para control basado en zona + identidad | NIST AC-3(7) ZTA · NGAC INCITS 565-2020 §4 · NIST SP 800-207 §3 |
| B04 | `fields` | Field-Level Access | Acceso a campos de datos con enmascaramiento y obligaciones PII. Patrón: el mismo usuario ve distintos campos según su rol. Integra con bi18n para masking localizado | NIST AC-3(9) · ISO 27001:2022 A.8.11 · OWASP ASVS v5 §4.1 |
| B05 | `contracts` | Access Contracts | Contratos de modo de acceso (READ_ONLY, APPEND_ONLY, FULL_CONTROL, etc.). Define el tipo de operación permitida, no solo si se permite | ISO/IEC 15408-2 · NIST AC-4 · XACML 3.0 §5.2 Obligations |
| B06 | `session` | Logical Session | Ciclo de vida de la sesión lógica — creación, validación, step-up, expiración, revocación. `session-revoked` y `token-claims-change` son eventos CAEP 1.0 Final (sep 2025) | NIST AC-12 · CAEP 1.0 Final (sep 2025) · RFC 9470 |
| B07 | `certification` | Access Recertification | Recertificación periódica de accesos (IGA — entitlement review). ¿Debería seguir teniendo este acceso? Campaña de revisión sobre `privilege_atom_grant` activos | NIST AC-2(7) · ISO 27002:2022 §5.18 · CIS Controls v8.1 §6 |
| B08 | `dynamic_policy` | Dynamic ABAC Policy | Políticas dinámicas ABAC/PBAC — `authorization_details` estructurados (RFC 9396 RAR). Evaluación contextual en tiempo real: atributos del sujeto + recurso + entorno | NIST CSF 2.0 PR.AA-04 · RFC 9396 (RAR) · NIST SP 800-162 §5 |
| B09 | `zona_negocios` | Business Zone Registry | Contenedor de aplicaciones del dominio lógico. Registra qué apps operan en este perímetro (prefijo `zona_logical_*`). 5 niveles internos: zona → model / actions / field / button / record_rule | NGAC INCITS 565-2020 §4 · SABSA SCF · XACML 3.0 §5.2 |

**Átomos de referencia:**
```
d01.authorization.approve       d01.authorization.execute
d01.roles.create                d01.roles.assign            d01.roles.delegate
d01.zones.access                d01.zones.configure
d01.fields.read                 d01.fields.export
d01.contracts.configure
d01.session.validate            d01.session.revoke          d01.session.step_up
d01.certification.approve       d01.certification.audit
d01.dynamic_policy.configure    d01.dynamic_policy.evaluate
d01.zona_negocios.register      d01.zona_negocios.configure
```

---

## 4. D02 — Control de Acceso Físico (8 bloques)

**Propósito:** PACS (Physical Access Control Systems) — zonas físicas, controladores OSDP,
credenciales temporales, anti-passback, visitantes, evacuación. ~30 roles. FastPath + canal
OSDP AES-128/256. El binario de imagen/credential NUNCA entra a bAuth — solo referencias.

**Pipeline:** FAST-PATH — evaluación por bit directa tras D01.

**Normas principales:** IEC 60839-11-5:2020 (OSDP v2) · SIA OSDP v2.2.2 (oct 2024) ·
NIST SP 800-116 R2 · ISO 19092:2008 · ISO 27001:2022 A.7 · NFPA 101:2021

**Investigación 2025-2026:** SIA OSDP v2.2.2 (octubre 2024) refuerza AES-256 GCM en el canal
seguro y añade extensiones para biometría on-reader (integración D05→D02). NIST SP 800-116
Rev.2 (2023) actualiza los requisitos PIV para PACS, incluyendo credenciales móviles (mDL).
ISO 45001:2018 (OH&S) es la norma de referencia para mustering/evacuación — OSHA 29 CFR
1910.38 exige planes de evacuación de emergencia con conteo de personal. El anti-passback
deja de ser implícito en presence para ser un control propio según IEC 60839-11-1 §6.4.

| Código | Slug canónico | Nombre BD | Descripción | Norma principal |
|--------|--------------|-----------|-------------|-----------------|
| B01 | `facilities` | Physical Facilities | Acceso a instalaciones físicas — puertas, torniquetes, barreras, zonas de seguridad. Control de quién entra a qué zona física y cuándo | IEC 60839-11-5:2020 §6 · ISO 19092:2008 §7 · ISO 27001 A.7.1 |
| B02 | `readers` | OSDP Readers | Configuración y auditoría de lectores OSDP — firmware, canal seguro AES-256, diagnóstico de tamper. SIA OSDP v2.2.2 extiende el protocolo para biometría on-reader | SIA OSDP v2.2.2 §4 · IEC 60839-11-5:2020 §8 |
| B03 | `presence` | Dual Presence / Mantrap | Verificación de presencia dual — mantrap (exclusa de seguridad), dos-persona-regla para acceso a zonas de alta seguridad. Previene tailgating | NIST SP 800-116 R2 §4.2 · IEC 60839-11-3 · ISO 19092:2008 §9 |
| B04 | `antipassback` | Anti-Passback | Prevención de reutilización de credencial en la misma sesión física. Garantiza que quien entró debe salir antes de volver a entrar. Control propio separado de presence | IEC 60839-11-1 §6.4 · ISO 27001:2022 A.7.2 |
| B05 | `visitors` | Visitor Access Management | Acceso temporal a terceros no empleados con auto-expiración. Ciclo de vida completo: pre-registro, check-in, escort, check-out, revocación automática | ISO 19092:2008 §8 · NIST AC-2(2) · ISO 27001:2022 A.7.2 |
| B06 | `emergency` | Physical Emergency Access | Break-glass físico — acceso de emergencia con doble aprobación a zonas normalmente restringidas. Aplica cuando sistemas PACS fallan o en evacuación dirigida | NIST SP 800-116 R2 §5.4 · NIST AC-17(3) · ISO 27001:2022 A.7.3 |
| B07 | `mustering` | Evacuation & Muster | Evacuación de emergencia — conteo de personal dentro de zona. ¿Quién salió, quién no? Integra con D08 `emergency` para activación de protocolo. Mandatorio OSHA/NFPA | ISO 27001:2022 A.7.4 · NFPA 101:2021 §7.7 · ISO 45001:2018 §8.2 |
| B08 | `zona_negocios` | Business Zone Registry | Contenedor de sistemas de control de acceso físico (PACS, lectores, actuadores). Prefijo `zona_fisica_*`. Niveles: device_access / location_rule / schedule_rule | NGAC INCITS 565-2020 §4 · IEC 60839-11-5 · ISO 27001:2022 A.7.1 |

**Átomos de referencia:**
```
d02.facilities.access           d02.facilities.configure    d02.facilities.audit
d02.readers.configure           d02.readers.audit           d02.readers.firmware_update
d02.presence.validate
d02.antipassback.validate       d02.antipassback.override
d02.visitors.create             d02.visitors.delete         d02.visitors.extend
d02.emergency.approve           d02.emergency.audit
d02.mustering.activate          d02.mustering.validate      d02.mustering.report
d02.zona_negocios.register
```

---

## 5. D03 — Controles Financieros (9 bloques)

**Propósito:** Límites transaccionales, aprobación dual, SoD financiero, facturación
electrónica Bolivia (SIN/SIAT), reportes regulatorios, detección de fraude, conciliación,
Open Banking. ~115 roles (tesorería, SWIFT, pasarelas, factoring, casa de cambios).

**Pipeline:** POLICY-PATH — evaluación con PolicyChain completa.

**Normas principales:** PCI DSS 4.0.1 (2024) · SOX §302/§404 · COSO 2013 ·
ISO 20022:2022 · SIN RND 102100000011 · FAPI 2.0 Security Profile · ISO 37001:2016

**Investigación 2025-2026:** PCI DSS 3.2.1 fue retirado el 31 de marzo de 2024; PCI DSS
4.0.1 es la versión vigente. El Req 10.7.3 exige detección de fallos de controles de seguridad
en tiempo real con alerta automatizada — base normativa del bloque `fraud`. Open Banking
Standard v4.0 + FAPI 2.0 (2024) amplían los requisitos de consentimiento granular de acceso
a cuenta bancaria: consent token, scope de cuenta, validez temporal — base del bloque
`open_banking`. ISO 37001:2016 (Anti-Bribery Management System) §8.6 incluye controles
financieros como medida antisoborno relevante para el bloque `fraud`. SIN Bolivia: el SIAT
(Sistema de Impuestos en Línea) migró a modalidad en línea obligatoria para todos los
contribuyentes a partir de 2024 — el bloque `billing` debe contemplar la integración SIAT.

| Código | Slug canónico | Nombre BD | Descripción | Norma principal |
|--------|--------------|-----------|-------------|-----------------|
| B01 | `limits` | Transactional Limits | Límites transaccionales — monto máximo, frecuencia, acumulado diario/mensual por rol/usuario. Control preventivo antes de ejecutar la transacción | PCI DSS 4.0.1 Req 7 · COSO 2013 CC6.3 · NIST AC-2(6) |
| B02 | `approvals` | Dual Approval / Quorum | Aprobación dual o quórum k-de-N para transacciones de alto valor. Implementa el principio de cuatro ojos. Integra con T-153 (pam_jit_approval) para flujo de aprobación | SOX §404 · COSO CC7.2 · NIST AC-5 · ISO 27001:2022 A.5.3 |
| B03 | `segregation` | Financial SoD | SoD financiero — separación de roles capturador/aprobador/conciliador. Conflict Matrix estático (definición) + dinámico (runtime). Previene fraude interno | SOX §404 · COSO Control Activities · NIST AC-5 · ISO 27001:2022 A.5.3 |
| B04 | `billing` | Electronic Invoicing | Factura electrónica Bolivia SIN (CUIS, CUFD, SIAT en línea). Integración con la API del SIAT: emisión, anulación, consulta. UBL 2.1 como formato estructurado | SIN RND 102100000011 · DS 27310 · ISO 20022 · UBL 2.1 OASIS |
| B05 | `reporting` | Regulatory Reporting | Reportes regulatorios — conciliación, cierre, SWIFT MT940/MX, reporte SOX §302. Generación de evidencia auditable para entes reguladores | SOX §302 · IFRS 7 · ISO 20022:2022 MX · SWIFT GPI |
| B06 | `fraud` | Fraud Detection | Detección de anomalías transaccionales (velocidad, monto, geografía, hora). PCI DSS 4.0.1 Req 10.7.3 exige detección en tiempo real con alerta automatizada desde marzo 2025 | PCI DSS 4.0.1 Req 10.7.3 · COSO CC7.3 · ISO 37001:2016 §8.6 |
| B07 | `reconciliation` | Automatic Reconciliation | Conciliación automática de cuentas y posiciones. Matching de registros contra extracto bancario. Excepciones a revisión humana | COSO 2013 CC7.4 · ISO 20022:2022 §5 · NIST CA-7 |
| B08 | `open_banking` | Open Banking / FAPI 2.0 | Consentimiento granular de acceso a cuenta bancaria. Consent token, scope de cuenta, validez temporal, revocación. FAPI 2.0 Security Profile sobre OAuth 2.0 + DPoP | FAPI 2.0 Security Profile · RFC 9449 (DPoP) · Open Banking v4.0 · PSD2 Art. 98 |
| B09 | `zona_negocios` | Business Zone Registry | Contenedor de módulos financieros (account_*, invoice, payment de Tryton; pasarelas de pago; SIAT). Prefijo `zona_financial_*` | NGAC INCITS 565-2020 §4 · COSO 2013 CC6 · PCI DSS 4.0.1 Req 7 |

**Átomos de referencia:**
```
d03.limits.configure            d03.limits.approve
d03.approvals.approve           d03.approvals.delegate
d03.segregation.validate        d03.segregation.configure
d03.billing.emit                d03.billing.validate        d03.billing.audit
d03.reporting.read              d03.reporting.emit
d03.fraud.validate              d03.fraud.alert
d03.reconciliation.execute      d03.reconciliation.review
d03.open_banking.consent_create d03.open_banking.consent_revoke d03.open_banking.validate
d03.zona_negocios.register
```

---

## 6. D04 — Acceso Temporal (6 bloques)

**Propósito:** Horarios, turnos, feriados, ventanas temporales de acceso. El cajero entra
solo en su turno; el batch nocturno corre solo entre 23:00 y 04:00. 155 roles (N4+N5).
Encadenado a D01 vía PolicyChainResolver — sin bits propios.

**Pipeline:** POLICY-PATH — encadenado a átomos D01.

**Normas principales:** GTRBAC (Bertino et al., IEEE TDKE 2005) · RFC 5545 iCalendar ·
ISO 8601:2019 · NIST SP 800-53 R5.2 AC-2(2) · AC-17(1)

**Investigación 2025-2026:** GTRBAC sigue siendo la referencia académica más completa para
RBAC con restricciones temporales. PostgreSQL 18 introduce soporte nativo de `WITHOUT OVERLAPS`
y tipos `PERIOD` — base técnica para implementar los tres estados de rol GTRBAC
(`disabled`/`enabled`/`active`) directamente en SQL sin tablas auxiliares de versión. RFC 5545
iCalendar sigue vigente; su extensión CalDAV (RFC 4791) permite integración con calendarios
corporativos para feriados y turnos. NIST SP 800-53 R5.2 (agosto 2025) refuerza AC-2(2):
las cuentas temporales deben expirar automáticamente sin intervención manual.

| Código | Slug canónico | Nombre BD | Descripción | Norma principal |
|--------|--------------|-----------|-------------|-----------------|
| B01 | `windows` | Time Windows | Ventanas de tiempo válidas para acceso — horario laboral, turnos por jornada. Implementa `role enabling` GTRBAC §3: el rol solo existe dentro de la ventana | GTRBAC §3.2 · ISO 8601 §4 · NIST AC-3(7) |
| B02 | `periods` | Assignment Periods | Duración de asignación temporal — expiración de rol/permiso. Implementa `duration constraints` GTRBAC §4. PG18 `WITHOUT OVERLAPS` garantiza no-solapamiento | GTRBAC §4 · ISO 8601 §5 · PostgreSQL 18 PERIOD |
| B03 | `calendar` | Calendar & Holidays | Calendario de feriados y excepciones por país/tenant. Días hábiles, días feriados, días especiales. Integración con bcalendar daemon | RFC 5545 iCalendar §3.8 · ISO 8601 · CalDAV RFC 4791 |
| B04 | `schedules` | Shift Rotation | Rotación de turnos (mañana/tarde/noche) con herencia temporal. Implementa `periodicity constraints` GTRBAC §5. Asignación de turnos a grupos de usuarios | GTRBAC §5 · NIST AC-2(2) · RFC 5545 RRULE |
| B05 | `exceptions` | Schedule Exceptions | Excepciones de horario — horas extra, guardia, emergencia, trabajo en feriado. Requieren aprobación con doble control. Registro WORM de la excepción | GTRBAC §6 · NIST AC-17(1) · ISO 27001:2022 A.5.18 |
| B06 | `zona_negocios` | Business Zone Registry | Contenedor de sistemas de calendario, gestión de turnos y schedulers. Prefijo `zona_temporal_*`. Niveles: time_window / calendar_rule / expiry_policy | NGAC INCITS 565-2020 §4 · GTRBAC §3 · NIST AC-2(2) |

**Átomos de referencia:**
```
d04.windows.configure           d04.windows.validate
d04.periods.configure           d04.periods.validate
d04.calendar.configure          d04.calendar.read
d04.schedules.configure         d04.schedules.assign
d04.exceptions.approve          d04.exceptions.audit
d04.zona_negocios.register
```

---

## 7. D05 — Autenticación Biométrica (7 bloques)

**Propósito:** Enrolamiento biométrico, verificación (1:1), detección de ataques de
presentación (PAD/liveness), identificación (1:N), calidad de muestra, revocación de template.
~34 roles. External-Path vía bhnexus. El binario biométrico NUNCA entra a bAuth — solo `ref://`.

**Pipeline:** EXTERNAL-PATH — vía bhnexus hacia motor biométrico externo.

**Normas principales:** ISO/IEC 30107-3:2023 (PAD) · ISO/IEC 29794-1:2024 (calidad) ·
NIST SP 800-63B-4 §5.2.3 (AAL3 biométrico) · ISO/IEC 19794-2:2011 · ISO/IEC 24745:2022

**Investigación 2025-2026:** ISO/IEC 30107-3:2023 agrega la métrica **RIAPAR** (Relative
Impact of Attacks Per Recognition Attempt Rate) y formaliza IAD (Injection Attack Detection)
como categoría — los ataques digitales (bypass vía inyección de video) son tan relevantes
como los físicos. ISO/IEC 29794-1:**2024** convierte la calidad de muestra biométrica en
norma ISO formal — ya no es solo buena práctica. TÜV Rheinland certificó productos al nivel
ISO/IEC 30107-3 Level C (el más alto) en 2025. NIST SP 800-63B-4 §5.2.3 establece que
la biometría como AAL3 requiere verificación in-person con supervisor humano O un sistema
PAD certificado ISO/IEC 30107-3 Level 2+. INTERPOL publica estándares de identificación
biométrica 1:N para uso policial — relevante si el sistema D05 cubre casos SEGIP/migración.

| Código | Slug canónico | Nombre BD | Descripción | Norma principal |
|--------|--------------|-----------|-------------|-----------------|
| B01 | `enrollment` | Biometric Enrollment | Captura y registro de template biométrico. Calidad mínima de muestra (B05 previo). Referencia `ref://` almacenada, binario en motor externo | ISO/IEC 19794-2:2011 §4 · NIST SP 800-63A-4 §5 (IAL3) · ISO/IEC 30107-1 |
| B02 | `verification` | 1:1 Biometric Verification | Comparación 1:1 contra template registrado. FAR/FRR definidos por política del tenant. Resultado booleano + score de confianza | ISO/IEC 30107-1 §5 · NIST SP 800-63B-4 §5.2.3 · ISO/IEC 19794-2:2011 §5 |
| B03 | `liveness` | Liveness Detection (PAD) | Detección de ataque de presentación (PAD) y anti-spoofing. Métricas APAR/BPAR/RIAPAR (ISO/IEC 30107-3:2023). IAD: detección de inyección de video digital | ISO/IEC 30107-3:2023 §5 · FIDO2 §8.8 · NIST SP 800-63B-4 §5.2.3 |
| B04 | `identification` | 1:N Biometric Identification | Comparación 1:N — buscar al sujeto en una base de templates sin conocer su identidad previa. Casos de uso: SEGIP, migración, control de fronteras | ISO/IEC 30107-1 §6 · ISO/IEC 19794-2:2011 §6 · INTERPOL standards |
| B05 | `quality` | Biometric Sample Quality | Verificación de calidad del sample biométrico antes de capturar. ISO/IEC 29794-1:2024 es norma formal — define métricas de calidad (NFIQ para huellas, ICAO para rostro) | ISO/IEC 29794-1:2024 §5 · NIST SP 800-76-2 §3 · ICAO Doc 9303 |
| B06 | `revocation` | Biometric Template Revocation | Revocación de template biométrico comprometido. Escenarios: robo de base de datos biométrica, cambio físico del rasgo, solicitud del sujeto | ISO/IEC 24745:2022 §6 · NIST SP 800-63B-4 §5.2.6 · ISO/IEC 30107-1 |
| B07 | `zona_negocios` | Business Zone Registry | Contenedor de sistemas de captura y verificación biométrica. Prefijo `zona_biometric_*`. Niveles: biometric_method / liveness_check / fallback_policy | NGAC INCITS 565-2020 §4 · ISO/IEC 19794-1:2011 · NIST SP 800-76-2 |

**Átomos de referencia:**
```
d05.enrollment.create           d05.enrollment.delete       d05.enrollment.audit
d05.verification.validate
d05.liveness.validate
d05.identification.search
d05.quality.validate
d05.revocation.execute          d05.revocation.audit
d05.zona_negocios.register
```

---

## 8. D06 — Acceso Geoespacial (6 bloques)

**Propósito:** Geocercas, viaje imposible, soberanía de datos por jurisdicción, flota.
~54 roles. Encadenado a D01 vía PolicyChainResolver. External-Path.

**Pipeline:** EXTERNAL-PATH — encadenado a átomos D01.

**Normas principales:** RFC 7946 GeoJSON · OGC GeoSPARQL 1.1 · OGC GeoFence v1.0 ·
NIST SP 800-207 §3.3 · GDPR Art. 44-49 · Ley 1174 Bolivia · ISO 6709:2022

**Investigación 2025-2026:** OGC GeoSPARQL 1.1 (2022) es el estándar W3C/OGC vigente para
consultas geoespaciales semánticas. NIST SP 800-207 §3.3 incorpora la ubicación como señal
de contexto obligatoria en arquitecturas Zero Trust — el viaje imposible (`velocity`) es una
de las señales más citadas por CISA ZTA Maturity Model v2.0 (2023). GDPR Art. 44-49 regula
las transferencias internacionales de datos — el bloque `residency` implementa la soberanía
de datos como control técnico. Ley 1174 Bolivia (Protección de Datos Personales, 2019)
exige que los datos de ciudadanos bolivianos residan en Bolivia o en países con nivel
equivalente de protección. ISO 6709:2022 actualiza el estándar de representación de
coordenadas geográficas con soporte nativo de altitud y sistemas de referencia extendidos.

| Código | Slug canónico | Nombre BD | Descripción | Norma principal |
|--------|--------------|-----------|-------------|-----------------|
| B01 | `geofencing` | Geofences | Definición y evaluación de geocercas — ¿está el sujeto dentro del polígono permitido? GeoJSON como formato de definición. Integra con D08 `risk` para señal de contexto | RFC 7946 GeoJSON §3.1 · OGC GeoSPARQL 1.1 · OGC GeoFence v1.0 |
| B02 | `location` | Location Validation | Validación de ubicación puntual del sujeto (lat/lon/alt). Precisión mínima, fuente de dato (GPS/WiFi/IP). Señal ZTA según NIST SP 800-207 §3.3 | RFC 7946 §3 · NIST SP 800-207 §3.3 · CISA ZTA Maturity Model v2.0 |
| B03 | `velocity` | Impossible Travel Detection | Detección de viaje imposible (>velocidad física posible entre dos autenticaciones en diferentes ubicaciones). Patrón UEBA ampliamente adoptado. Señal NIST SP 800-207 §3.3 | NIST SP 800-207 §3.3 · NIST SP 800-53 R5.2 SI-4(13) · ISO 27001 A.8.16 |
| B04 | `residency` | Data Sovereignty & Residency | Soberanía de datos — ¿el procesamiento respeta la jurisdicción de origen del dato? Controla dónde se procesa información según la nacionalidad/domicilio del sujeto | GDPR Art. 44-49 · Ley 1174 Bolivia · ISO 3166-1 · NIST SP 800-53 R5.2 SA-9(5) |
| B05 | `fleet` | Fleet-Based Access | Gestión de acceso basada en ubicación de flota (vehículos, drones, activos móviles con identidad geográfica). Integra posición del activo con derechos de acceso | ISO 6709:2022 · OGC MovingFeatures · NIST AC-3(11) |
| B06 | `zona_negocios` | Business Zone Registry | Contenedor de sistemas de geofencing, mapas y control de ubicación. Prefijo `zona_geo_*`. Niveles: geofence / country_rule / ip_region_rule | NGAC INCITS 565-2020 §4 · RFC 7946 §3 · ISO 6709:2022 |

**Átomos de referencia:**
```
d06.geofencing.configure        d06.geofencing.validate
d06.location.validate
d06.velocity.validate           d06.velocity.alert
d06.residency.validate          d06.residency.configure
d06.fleet.validate              d06.fleet.register
d06.zona_negocios.register
```

---

## 9. D07 — Seguridad de Red (8 bloques)

**Propósito:** ZTNA (Zero Trust Network Access) — CIDR, mTLS, DPoP, postura del dispositivo,
micro-segmentación, DLP, propagación de contexto. Kong es el PEP; bAuth el PDP.
Sin roles propios directos — todos los roles pasan por D07 en borde.

**Pipeline:** EXTERNAL-PATH — Kong como PEP, bAuth como PDP.

**Normas principales:** NIST SP 800-207:2020 (ZTA) · NIST SP 800-207A (cloud-native ZTA) ·
RFC 9449 (DPoP) · RFC 8705 (mTLS OAuth 2.0) · W3C Trace Context v2 ·
OWASP API Security 2023 · CIS Controls v8 §13

**Investigación 2025-2026:** NIST SP 800-207A (2023) amplía ZTA con guía cloud-native:
identity-based micro-segmentation como el modelo más robusto. CISA ZTA Maturity Model v2.0
(2023) incorpora `Network Posture` como dimensión explícita del pilar de red. RFC 9449 (DPoP)
es Proposed Standard desde 2023 — proof-of-possession para access tokens sin necesidad de
mTLS completo. W3C Trace Context v2 (Recomendación 2024) y W3C Baggage (Recomendación 2023)
son los estándares para propagación de contexto en sistemas distribuidos — el bloque
`propagation` implementa estos headers para observabilidad distribuida. OWASP API Security
Top 10 2023 actualiza los riesgos: "Broken Object Level Authorization" y "Unrestricted
Resource Consumption" son los nuevos #1 y #4.

| Código | Slug canónico | Nombre BD | Descripción | Norma principal |
|--------|--------------|-----------|-------------|-----------------|
| B01 | `connection` | mTLS / CIDR Connection | Validación de conexión — mTLS presente y válido, CIDR dentro del rango permitido. Binding de certificado cliente a identidad del daemon | RFC 8705 §2 · NIST SP 800-207 §4 · NIST SP 800-52 R2 |
| B02 | `tokens` | DPoP / PKCE Tokens | Proof-of-Possession de token (DPoP/PKCE) para evitar replay y token theft. DPoP vincula el token al par de claves del cliente. PKCE protege el flujo de autorización | RFC 9449 (DPoP) §4 · RFC 7636 (PKCE) §4 |
| B03 | `rate` | Rate Limiting | Rate limiting por usuario/IP/ruta — prevención de abuso y DoS. Tokens por ventana temporal. Integra con Kong para enforcement en borde | OWASP API Security 2023 §6 · RFC 6585 §4 · NIST SI-10 |
| B04 | `posture` | Network Posture | Postura de red del punto de conexión — segmento correcto, VPN activa, reputación IP, EDR presente. Señal ZTA multi-dimensional | NIST SP 800-207 §3.2 · CISA ZTA Maturity Model v2.0 · BeyondCorp §4 |
| B05 | `segmentation` | Micro-segmentation | Micro-segmentación de red — control del tráfico east-west entre servicios. Cada daemon se comunica solo con sus pares autorizados vía Unix socket | NIST SP 800-207A §4 · CISA ZTA Pillar: Network · ISO 27001:2022 A.8.22 |
| B06 | `inspection` | DPI / DLP Inspection | Inspección de payload en tránsito (DPI/DLP para datos sensibles). Previene exfiltración de datos PII/PCI en tránsito | NIST SP 800-207 §4.4 · PCI DSS 4.0.1 Req 4 · NIST SP 800-53 R5.2 SI-3 |
| B07 | `propagation` | Context Propagation | Propagación de contexto inter-servicio con headers estándar W3C (`traceparent`, `tracestate`, Baggage). Sin este bloque la observabilidad distribuida es incompleta | W3C Trace Context v2 (Rec 2024) · W3C Baggage (Rec 2023) · OpenTelemetry §5 |
| B08 | `zona_negocios` | Business Zone Registry | Contenedor de sistemas de conectividad, proxies y gateways. Prefijo `zona_network_*`. Niveles: network_segment / protocol_rule / port_policy | NGAC INCITS 565-2020 §4 · NIST SP 800-207 §3 · ISO 27001:2022 A.8.22 |

**Átomos de referencia:**
```
d07.connection.validate         d07.connection.configure
d07.tokens.validate
d07.rate.configure              d07.rate.validate
d07.posture.validate
d07.segmentation.configure      d07.segmentation.validate
d07.inspection.configure        d07.inspection.alert
d07.propagation.configure       d07.propagation.validate
d07.zona_negocios.register
```

---

## 10. D08 — Contexto / Sesión (7 bloques)

**Propósito:** El ctx_id como pre-condición — sin contexto vivo no hay evaluación.
Contexto de sesión, riesgo continuo, postura de dispositivo, break-glass, assurance level,
ITDR. Pre-BitMask: falla antes de evaluar cualquier bit.

**Pipeline:** PRE-BITMASK — primer bloque del pipeline, antes de D09.

**Normas principales:** SBOS-049 (Context Plane) · W3C Trace Context v2 ·
OpenID CAEP 1.0 Final (sep 2025) · NIST AC-17(3) · NIST SP 800-53 R5.2 SI-4 ·
RFC 9470 (Step-Up Authentication)

**Investigación 2025-2026:** OpenID CAEP 1.0 (final septiembre 2025, parte de Shared Signals
Framework) define cinco tipos de evento canónicos: `session-revoked`, `risk-level-change`,
`device-compliance-change`, `assurance-level-change`, `token-claims-change`. El bloque
`assurance` implementa `assurance-level-change` como tipo formal. Gartner ITDR 2025 establece
que ITDR (Identity Threat Detection and Response) es la categoría de mercado 2025-2026 para
detección de amenazas basadas en señales de identidad (Golden Ticket, movimiento lateral,
abuso de sesión) — diferente de `risk` (evaluación continua) porque es retrospectivo forense.
NIST SP 800-53 R5.2 IR-4 actualiza los requisitos de respuesta a incidentes incluyendo
incidentes de identidad.

| Código | Slug canónico | Nombre BD | Descripción | Norma principal |
|--------|--------------|-----------|-------------|-----------------|
| B01 | `session` | ctx_id Lifecycle | Ciclo de vida del ctx_id — creación, validación, extensión, revocación. El ctx_id es la pre-condición de toda operación SBOS (SBOS-049). CAEP `session-revoked` | SBOS-049 · W3C Trace Context v2 · NIST AC-12 · CAEP 1.0 Final |
| B02 | `risk` | Continuous Risk Score | Score de riesgo continuo del sujeto — señales de comportamiento, UEBA, anomalías. CAEP `risk-level-change`. Alimenta el motor de step-up (D01 `session`) | CAEP 1.0 Final §4 · NIST SP 800-207 §3.3 · ISO 27001:2022 A.8.16 |
| B03 | `device` | Device Posture | Postura del dispositivo — MDM enrollment, parches al día, cifrado en reposo, EDR activo. CAEP `device-compliance-change`. Señal ZTA crítica | CAEP 1.0 Final §4 · NIST SP 800-124 R2 §4 · CIS Controls v8 §4 |
| B04 | `emergency` | Context Break-glass | Break-glass de contexto — acceso con doble aprobación a contextos normalmente protegidos cuando el flujo normal está impedido. Registra WORM el evento completo | NIST AC-17(3) · ISO 27001:2022 A.5.29 · NIST SP 800-53 R5.2 CP-2(8) |
| B05 | `assurance` | Active Assurance Level | Nivel de garantía de la sesión activa (current_loa: AAL1/2/3). `assurance-level-change` es tipo de evento CAEP 1.0 Final. Dispara step-up cuando el recurso requiere LoA mayor | CAEP 1.0 Final (sep 2025) §4 · NIST SP 800-63B-4 §4 · RFC 9470 §3 |
| B06 | `itdr` | Identity Threat Detection (ITDR) | Detección y respuesta a amenazas de identidad — Golden Ticket, movimiento lateral, abuso de sesión. Investigación retrospectiva + remediación. Diferente de `risk` (continuo): ITDR es forense | NIST SP 800-53 R5.2 SI-4 · IR-4 · Gartner ITDR 2025 · CAEP 1.0 Final §5 |
| B07 | `zona_negocios` | Business Zone Registry | Contenedor de sistemas de gestión de contexto y riesgo. Prefijo `zona_context_*`. Niveles: device_trust / risk_score_rule / session_context | NGAC INCITS 565-2020 §4 · SBOS-049 · W3C Trace Context v2 |

**Átomos de referencia:**
```
d08.session.validate            d08.session.delete          d08.session.extend
d08.risk.validate               d08.risk.audit              d08.risk.execute
d08.device.validate             d08.device.configure
d08.emergency.approve           d08.emergency.audit
d08.assurance.validate          d08.assurance.step_up
d08.itdr.investigate            d08.itdr.remediate          d08.itdr.report
d08.zona_negocios.register
```

---

## 11. D09 — Gestión de Credenciales (10 bloques)

**Propósito:** Credenciales del sujeto — contraseñas, MFA, certificados X.509, tokens de
acceso, revocación, recuperación de cuenta, binding de autenticador, passkeys, introspección.
Pre-BitMask. Único dominio con B10 (Business Zone Registry en posición 10).

**Pipeline:** PRE-BITMASK — evaluado antes de D01 (la credencial debe validarse antes de autorizar).

**Normas principales:** NIST SP 800-63B-4 (final julio 2024) · RFC 5280 (X.509) ·
W3C WebAuthn Level 3 · FIDO2 · RFC 7519 (JWT) · RFC 7662 (Introspección) ·
OWASP ASVS v5 §2 · RFC 6749 (OAuth 2.0)

**Investigación 2025-2026:** NIST SP 800-63B-4 (final julio 2024) eleva los passkeys (FIDO2)
a la base de AAL2 como credencial phishing-resistant — el bloque `passkey` deja de ser
experimental. La norma depreca el uso de SMS OTP como único factor AAL2. FIDO Alliance
publica estadísticas 2025: más del 13 billones de cuentas soportan passkeys a nivel global.
W3C WebAuthn Level 3 (CR 2024) añade soporte para passkeys multi-dispositivo y enterprise
attestation. RFC 7662 (Token Introspection) sigue siendo la referencia para el bloque
`introspection` — los authorization servers deben exponer un endpoint de introspección.
NIST SP 800-63B-4 §6.1 actualiza los requisitos de recuperación de cuenta: los recovery codes
no deben ser la única opción — debe haber un proceso verificado.

| Código | Slug canónico | Nombre BD | Descripción | Norma principal |
|--------|--------------|-----------|-------------|-----------------|
| B01 | `password` | Password Policy | Política de contraseñas — NIST 800-63B-4 §5.1.1: longitud mínima 8 chars, screening contra brechas conocidas (Have I Been Pwned), Argon2id como KDF. Sin reglas de complejidad arbitrarias | NIST SP 800-63B-4 §5.1.1 · OWASP ASVS v5 §2.1 |
| B02 | `mfa` | Multi-Factor Authentication | Autenticación multi-factor — TOTP, HOTP, FIDO2, push MFA, CIBA. Combina algo que tienes + algo que sabes o algo que eres. Obligatorio AAL2+ | NIST SP 800-63B-4 §5.1 · ISO 27001:2022 A.8.5 |
| B03 | `certificates` | X.509 Certificates | Certificados X.509 para mTLS y firma. Ciclo de vida: emisión (Vault PKI), renovación, revocación (OCSP). Integra con D13 para firma externa | RFC 5280 §4 · NIST SP 800-57 Pt1 R5 · RFC 6960 (OCSP) |
| B04 | `tokens` | Access Tokens | Tokens de acceso OAuth 2.0 / JWT. Ciclo de vida: emisión, validación, refresh, revocación. Claims canónicos: sub, iss, aud, exp, ctx_id, RolBitMask | RFC 7519 (JWT) §4 · RFC 6749 §5 · NIST SP 800-63B-4 §7 |
| B05 | `revocation` | Credential Revocation | Revocación de credenciales — contraseñas, tokens, certificados, biométricos. Revocación < 30 segundos para tokens activos. CAEP como canal de propagación | NIST SP 800-63B-4 §5.2.6 · ISO 27001:2022 A.5.17 · CAEP 1.0 Final |
| B06 | `recovery` | Account Recovery | Recuperación de cuenta — proceso verificado cuando el sujeto pierde acceso. Recovery codes como factor temporal (no único). Re-proofing de identidad según IAL | NIST SP 800-63B-4 §6.1 · OWASP ASVS v5 §2.5 |
| B07 | `binding` | Authenticator Binding | Vinculación de autenticador a cuenta — registro de dispositivo FIDO2, enrollment de certificado, asociación de TOTP. Proceso seguro con verificación de identidad previa | FIDO2 §6.1 · NIST SP 800-63B-4 §5.2.5 · W3C WebAuthn L3 |
| B08 | `passkey` | FIDO2 Passkeys | Passkeys FIDO2 — credencial phishing-resistant sincronizable entre dispositivos. Reemplaza contraseña + OTP como combo AAL2. Multi-device passkeys con cloud sync | W3C WebAuthn L3 §6.3 · NIST SP 800-63B-4 §5.2.2 · FIDO Alliance Passkey Spec 2024 |
| B09 | `introspection` | Token Introspection | Introspección de token — verificación del estado activo/revocado de un token por authorization servers y resource servers. Endpoint `/introspect` RFC 7662 | RFC 7662 §2 · RFC 6749 §7 · NIST SP 800-63B-4 §7 |
| B10 | `zona_negocios` | Business Zone Registry | Contenedor de aplicaciones de gestión de credenciales. Prefijo `zona_credential_*`. Posición B10 — único dominio con 10 bloques | NGAC INCITS 565-2020 §4 · NIST SP 800-63B-4 §5 · ISO 27001:2022 A.5.17 |

**Átomos de referencia:**
```
d09.password.validate           d09.password.change         d09.password.reset
d09.mfa.enroll                  d09.mfa.validate            d09.mfa.revoke
d09.certificates.issue          d09.certificates.revoke     d09.certificates.validate
d09.tokens.issue                d09.tokens.validate         d09.tokens.revoke
d09.revocation.execute          d09.revocation.audit
d09.recovery.initiate           d09.recovery.validate       d09.recovery.complete
d09.binding.register            d09.binding.delete
d09.passkey.register            d09.passkey.authenticate
d09.introspection.query
d09.zona_negocios.register
```

---

## 12. D10 — Delegación e Impersonación (7 bloques)

**Propósito:** Delegación de autoridad entre sujetos — un gerente delega aprobación a su
suplente, un servicio actúa en nombre de un usuario. Restricciones: SoD, cadenas, auditoría.
Integra con RFC 8693 (Token Exchange) para delegación técnica.

**Pipeline:** POLICY-PATH — PolicyChain completa para validar la cadena de delegación.

**Normas principales:** RFC 8693 (Token Exchange) · ANSI INCITS 359-2004 §4.5 ·
RFC 9396 (RAR) · NIST AC-2(5) · NIST AC-5 · ISO 27001:2022 A.5.18

**Investigación 2025-2026:** RFC 8693 (OAuth 2.0 Token Exchange) es la referencia técnica
para delegación — permite que un servicio obtenga un token actuando en nombre de otro sujeto
con scope restringido. RFC 9396 (RAR — Rich Authorization Requests) formaliza
`authorization_details` para delegaciones granulares. INCITS 359:2012 R2022 (revisado 2022)
mantiene §4.5 como el modelo de referencia para delegación RBAC. La cadena de delegación
debe ser auditable end-to-end: cada eslabón registrado en WORM.

> **Nota de discrepancia resuelta:** A.65.03 nombra B03 como `restrictions` (restricciones
> genéricas de delegación). La BD lo registra como `SoD Validation`. Se adopta el nombre de
> la BD como canónico. El bloque cubre validación de SoD antes de ejecutar una delegación —
> más específico y normativo que `restrictions`. Las restricciones genéricas se cubren
> implícitamente por los demás bloques.

| Código | Slug canónico | Nombre BD | Descripción | Norma principal |
|--------|--------------|-----------|-------------|-----------------|
| B01 | `delegation` | Delegation Management | Gestión del ciclo de vida de delegaciones — creación, vigencia, alcance, revocación. Un sujeto delega capacidades específicas a otro, no necesariamente todas las propias | RFC 8693 §3 · INCITS 359-2004 §4.5 · NIST AC-2(5) |
| B02 | `renewal` | Delegation Renewal | Renovación de delegación vencida o próxima a vencer. Requiere re-autorización del delegante. Límite de renovaciones sucesivas para prevenir acumulación indefinida | RFC 8693 §4.2 · ISO 27001:2022 A.5.18 · NIST AC-2(2) |
| B03 | `sod_validation` | SoD Validation | Validación de Segregación de Funciones antes de ejecutar la delegación. ¿El delegatario ya tiene un rol conflictivo con lo que se le quiere delegar? Previene fraude por delegación | NIST AC-5 · INCITS 359-2004 §4.4 · ISO 27001:2022 A.5.3 |
| B04 | `chain` | Chain Delegation | Delegación en cadena — el delegatario puede sub-delegar a un tercero dentro de los límites originales. Nunca se puede delegar más de lo que se tiene | RFC 8693 §2 · INCITS 359-2004 §4.5 · NIST AC-2(5) |
| B05 | `audit` | Delegation Auditability | Auditoría completa de la cadena de delegación — quién delegó a quién, qué, cuándo, con qué alcance. Registro WORM. Exportable para auditoría regulatoria | ISO 27001:2022 A.8.15 · NIST AU-2 · SOX §404 |
| B06 | `rich_authorization` | Granular API Authorization (RAR) | Autorización granular mediante `authorization_details` estructurados (RFC 9396 RAR). Permite especificar el alcance exacto de una delegación: recurso, acción, condición | RFC 9396 §3 · RFC 6749 · XACML 3.0 §5.2 |
| B07 | `zona_negocios` | Business Zone Registry | Contenedor de aplicaciones de delegación. Prefijo `zona_delegation_*`. Niveles: delegation_scope / chain_limit / audit_rule | NGAC INCITS 565-2020 §4 · RFC 8693 · NIST AC-2(5) |

**Átomos de referencia:**
```
d10.delegation.create           d10.delegation.revoke       d10.delegation.validate
d10.renewal.approve             d10.renewal.audit
d10.sod_validation.validate     d10.sod_validation.configure
d10.chain.create                d10.chain.validate
d10.audit.read                  d10.audit.export
d10.rich_authorization.configure d10.rich_authorization.validate
d10.zona_negocios.register
```

---

## 13. D11 — Auditoría y Cumplimiento (7 bloques)

**Propósito:** Captura de eventos de auditoría, retención legal, integridad hash-chain WORM,
monitoreo activo, exportación a SIEM, revisión periódica de accesos. Todos los daemons
emiten eventos de auditoría conformes con este dominio.

**Pipeline:** TRANSVERSAL — todos los dominios emiten eventos D11 en cada operación.

**Normas principales:** ISO 27001:2022 A.8.15 · NIST SP 800-53 R5.2 AU-2/AU-9/AU-11 ·
PCI DSS 4.0.1 Req 10 · SOX §802 · GDPR Art. 5(e) (limitación de almacenamiento)

**Investigación 2025-2026:** NIST SP 800-53 R5.2 (agosto 2025) refuerza AU-9: la integridad
de los logs debe verificarse criptográficamente — base del bloque `integrity` con hash-chain.
PCI DSS 4.0.1 Req 10.7.3 exige detección de fallos de controles en tiempo real — el bloque
`monitoring` implementa esto. ISO 27001:2022 A.5.35 (revisión independiente de seguridad
de la información) respalda el bloque `review`. El período de retención varía por norma:
PCI DSS Req 10.7: 12 meses online + 12 archivo · SOX §802: 7 años · GDPR: solo el mínimo
necesario · Ley 843 Bolivia: 10 años para documentación fiscal.

| Código | Slug canónico | Nombre BD | Descripción | Norma principal |
|--------|--------------|-----------|-------------|-----------------|
| B01 | `events` | Event Capture | Captura de eventos de auditoría con timestamp, ctx_id, actor, acción, recurso, resultado, firma digital. Esquema canónico ISO 27001 A.8.15. Inmutables post-emisión | ISO 27001:2022 A.8.15 · NIST AU-2 · RFC 3881 |
| B02 | `retention` | Retention Policy | Política de retención por tipo de evento y entidad regulatoria. Retención diferenciada: PCI 12m+12m / SOX 7 años / Ley 843 10 años. Purga automática con certificado de destrucción | NIST AU-11 · GDPR Art. 5(e) · SOX §802 · Ley 843 Bolivia |
| B03 | `integrity` | Hash-Chain Integrity | Integridad hash-chain WORM — cada evento enlaza al hash del anterior. Verificación criptográfica de que no se alteraron logs históricos. Implementado en `bauth_44` | NIST AU-9 · RFC 6962 §2.1 · ISO 27001:2022 A.8.15 |
| B04 | `monitoring` | Active Monitoring | Monitoreo activo de eventos de seguridad en tiempo real. Detección de fallos de controles (PCI DSS 4.0.1 Req 10.7.3). Alertas automatizadas ante umbrales | NIST AU-6 · PCI DSS 4.0.1 Req 10.7.3 · ISO 27001:2022 A.8.16 |
| B05 | `export` | SIEM Export | Exportación de eventos a SIEM (Wazuh). Formato syslog estándar. Integración con NIST AU-9(2): protección de logs en host remoto independiente | NIST AU-9(2) · ISO 27001:2022 A.8.15 · RFC 5424 (Syslog) |
| B06 | `review` | Periodic Review | Revisión periódica de accesos y eventos de auditoría. Campañas de recertificación (IGA). Reporte de anomalías para auditoría interna/externa | NIST AU-6 · ISO 27001:2022 A.5.35 · SOX §302 |
| B07 | `zona_negocios` | Business Zone Registry | Contenedor de aplicaciones de auditoría. Prefijo `zona_audit_*`. Niveles: event_type / retention_rule / monitoring_threshold | NGAC INCITS 565-2020 §4 · ISO 27001:2022 A.8.15 · SOX §802 |

**Átomos de referencia:**
```
d11.events.emit                 d11.events.read             d11.events.search
d11.retention.configure         d11.retention.execute
d11.integrity.verify            d11.integrity.alert
d11.monitoring.configure        d11.monitoring.alert
d11.export.configure            d11.export.execute
d11.review.initiate             d11.review.report
d11.zona_negocios.register
```

---

## 14. D12 — Anclaje Blockchain (7 bloques)

**Propósito:** Anclaje de hashes en Hyperledger Besu (QBFT), transacciones blockchain,
gestión de wallet, pruebas Merkle, DIDs, consenso. Complementa la firma digital interna
(Vault Ed25519) con el registro inmutable en cadena de bloques.

**Pipeline:** EXTERNAL-PATH — vía Besu node.

**Normas principales:** RFC 6962 §2.1 (Merkle) · Hyperledger Besu (QBFT) ·
EIP-712 · W3C DID Core v1.1 (CR marzo 2026) · W3C VC Data Model 2.0 · NIST IR 8202

**Investigación 2025-2026:** W3C DID Core v1.1 alcanzó Candidate Recommendation en marzo
2026 — los Decentralized Identifiers están en camino a Recomendación plena. W3C VC Data Model
2.0 es Recomendación desde mayo 2025. EIP-712 (Ethereum typed structured data hashing and
signing) es el estándar de facto para firmas estructuradas en EVM. QBFT (Quorum Byzantine
Fault Tolerant) es el algoritmo de consenso recomendado por Hyperledger Besu para redes
permisionadas — reemplaza a IBFT 2.0 como el más robusto. NIST IR 8202 (Blockchain Technology
Overview) es el documento de referencia normativa — su peso es informativo, no prescriptivo.
EIP-1559 (base fee + priority fee) es el modelo de transacción vigente en Besu.

| Código | Slug canónico | Nombre BD | Descripción | Norma principal |
|--------|--------------|-----------|-------------|-----------------|
| B01 | `anchoring` | Merkle Hash Anchoring | Anclaje de hashes de documentos/eventos en Besu vía árbol Merkle. La raíz Merkle se registra on-chain. Permite probar la existencia de un documento en una fecha | RFC 6962 §2.1 · EIP-712 · NIST SP 800-208 |
| B02 | `transactions` | Besu Transactions | Gestión de transacciones en Hyperledger Besu — firma, envío, confirmación, recibo. EIP-1559 para fee model. Gas estimation y retry con backoff | Hyperledger Besu §6 · EIP-1559 · EIP-712 |
| B03 | `wallet` | Wallet Management | Gestión de wallets blockchain — generación de keypairs (BIP-32/39/44), derivación de cuentas, custodia de claves privadas en Vault. Una wallet por tenant | BIP-32/39/44 · EIP-712 · NIST SP 800-208 |
| B04 | `merkle` | Merkle Proofs | Generación y verificación de pruebas de inclusión Merkle. Un tercero puede verificar que un documento estaba en el árbol sin necesidad del árbol completo | RFC 6962 §2.1.1 · NIST SP 800-208 §3 |
| B05 | `did` | Decentralized Identities (DID) | Emisión y resolución de Decentralized Identifiers (DIDs) anclados en Besu. did:besu:XXXX. Soporte a W3C DID Core v1.1 (CR marzo 2026) | W3C DID Core v1.1 (CR mar 2026) · W3C VC Data Model 2.0 |
| B06 | `consensus` | QBFT Consensus | Gestión del nodo QBFT (Quorum Byzantine Fault Tolerant) — estado del nodo, peers, votación, health. QBFT tolera hasta f fallos con 3f+1 nodos | Hyperledger Besu §4 · EIP-225 · QBFT Spec |
| B07 | `zona_negocios` | Business Zone Registry | Contenedor de aplicaciones blockchain. Prefijo `zona_blockchain_*`. Niveles: chain_operation / anchor_policy / did_registry | NGAC INCITS 565-2020 §4 · Hyperledger Besu QBFT · EIP-712 |

**Átomos de referencia:**
```
d12.anchoring.execute           d12.anchoring.verify
d12.transactions.submit         d12.transactions.query
d12.wallet.create               d12.wallet.sign             d12.wallet.audit
d12.merkle.generate             d12.merkle.verify
d12.did.create                  d12.did.resolve             d12.did.deactivate
d12.consensus.status            d12.consensus.audit
d12.zona_negocios.register
```

---

## 15. D13 — Firma Digital Externa (8 bloques)

**Propósito:** Firma de documentos con validez jurídica (Ley 164 Bolivia), cadena de
certificación CA/ADSIB, sello de tiempo (TSA), verificación de firma, revocación OCSP/CRL,
preservación a largo plazo (LTV), EUDI Wallet (eIDAS 2.0). Motor externo — bAuth orquesta.

**Pipeline:** EXTERNAL-PATH — vía ADSIB/SIN Bolivia para firma con validez jurídica.

**Normas principales:** Ley 164 Bolivia (Ley General de Telecomunicaciones) ·
DS 5519/AGETIC (ene 2026) · ETSI EN 319 102 (PAdES/CAdES/XAdES) · RFC 3161 (TSA) ·
RFC 5280 · eIDAS 2.0 (Reglamento UE 2024/1183) · ARF 1.4

**Investigación 2025-2026:** AGETIC fue disuelta por DS 5519 (enero 2026); sus funciones
de certificación digital se transfieren al Ministerio de Tecnologías — el bloque `certification`
debe reflejar este cambio. eIDAS 2.0 (Reglamento UE 2024/1183) introduce la EUDI Wallet como
wallet de identidad digital europea con plena validez jurídica — relevante para empresas
bolivianas con operaciones en Europa. ETSI EN 319 102-2 (validación de firma a largo plazo)
define LTV como el proceso de añadir material de validación (OCSP responses, CRL timestamps)
que permita validar la firma décadas después de su creación. PAdES-LTA (Long-Term Archive)
es el formato ETSI estándar para archivado de largo plazo.

| Código | Slug canónico | Nombre BD | Descripción | Norma principal |
|--------|--------------|-----------|-------------|-----------------|
| B01 | `signing` | Document Signing | Firma de documentos con validez jurídica boliviana (Ley 164). Formatos PAdES/CAdES/XAdES. Motor: ADSIB/Ministerio de Tecnologías + motor interno Vault Ed25519 | Ley 164 Bolivia · PAdES EN 319 132 · CAdES EN 319 122 |
| B02 | `certification` | CA Certification Chain | Cadena de certificación CA — emisión, renovación, validación de certificados. Post-DS 5519: AGETIC→Ministerio de Tecnologías. PKI boliviana + Vault PKI interno | RFC 5280 §6 · ETSI EN 319 412 · DS 5519/AGETIC (ene 2026) |
| B03 | `timestamping` | Timestamp (TSA) | Sello de tiempo de Autoridad de Sellado (TSA) — RFC 3161. Vincula el hash del documento a un timestamp de confianza. ADSIB/SIN como TSA reconocida | RFC 3161 §2 · ETSI EN 319 421 · Ley 164 Bolivia Art. 20 |
| B04 | `verification` | Signature Verification | Verificación de firma digital — ¿es válida la firma, el certificado y la cadena de confianza en el momento de la verificación? Incluye revocación OCSP | ETSI EN 319 102-1 §5 · RFC 5280 · Ley 164 Bolivia |
| B05 | `revocation` | OCSP / CRL Revocation | Verificación de revocación de certificados — OCSP (online) o CRL (descarga). Estado: valid/revoked/unknown. Caché de respuestas OCSP para rendimiento | RFC 6960 (OCSP) §2 · RFC 5280 §5 (CRL) · ETSI EN 319 412 |
| B06 | `long_term` | LTV Preservation | Preservación a largo plazo (LTV — Long-Term Validation). Añade material de validación (OCSP stapled, CRL archived) que permite verificar la firma décadas después | ETSI EN 319 102-2 §5.6 · RFC 3161 §3 · PAdES-LTA ETSI |
| B07 | `eudi_wallet` | EUDI Wallet (eIDAS 2.0) | Integración con European Digital Identity Wallet (eIDAS 2.0). Emisión de credenciales verificables en formato EUDI. Relevante para empresas con operaciones en Europa | eIDAS 2.0 Reglamento UE 2024/1183 §5a · ARF 1.4 · W3C VC Data Model 2.0 |
| B08 | `zona_negocios` | Business Zone Registry | Contenedor de aplicaciones de firma digital. Prefijo `zona_signature_*`. Niveles: signing_authority / cert_chain / timestamp_policy | NGAC INCITS 565-2020 §4 · ETSI EN 319 102 · Ley 164 Bolivia |

**Átomos de referencia:**
```
d13.signing.execute             d13.signing.verify          d13.signing.audit
d13.certification.issue         d13.certification.revoke    d13.certification.validate
d13.timestamping.stamp          d13.timestamping.verify
d13.verification.validate
d13.revocation.check            d13.revocation.cache
d13.long_term.preserve          d13.long_term.validate
d13.eudi_wallet.issue           d13.eudi_wallet.verify
d13.zona_negocios.register
```

---

## 16. D14 — Gestión de Acceso Privilegiado (PAM) (7 bloques)

**Propósito:** PAM — inventario de cuentas privilegiadas, bóveda de credenciales, JIT access,
brokering de sesión privilegiada, revisión de privilegios, grabación de sesión. Dominio de
mayor riesgo: controla el acceso a las "llaves del reino".

**Pipeline:** POLICY-PATH — PolicyChain completa + doble aprobación obligatoria.

**Normas principales:** NIST SP 800-53 R5.2 AC-6/AC-2(7) · CIS Controls v8 §5 ·
Gartner PAM Magic Quadrant 2025 · ISO 27001:2022 A.8.18 · NIST AU-14

**Investigación 2025-2026:** Gartner PAM Magic Quadrant 2025 consolida PAM como categoría
crítica — líderes implementan las 7 capacidades aquí formalizadas. NIST SP 800-53 R5.2 AC-6
(agosto 2025) refuerza el principio de mínimo privilegio con énfasis en JIT y privilege
just-enough-access (JEA). CIS Controls v8.1 §5.4 (privileged access) exige que las cuentas
privilegiadas no se usen para actividades cotidianas. La grabación de sesión (AU-14) es
requisito de muchas regulaciones financieras para cuentas admin.

> **Nota de discrepancia resuelta:** A.65.03 nombra B01 como `discovery` (descubrimiento
> activo de cuentas privilegiadas en la red). La BD lo registra como `Privileged Account
> Inventory`. Se adopta el nombre de la BD. El concepto es más preciso: bAuth mantiene
> un inventario de cuentas privilegiadas registradas, no un scanner de red. El descubrimiento
> activo (scanning) es responsabilidad de herramientas externas (CyberArk, BeyondTrust)
> que alimentan el inventario.

| Código | Slug canónico | Nombre BD | Descripción | Norma principal |
|--------|--------------|-----------|-------------|-----------------|
| B01 | `discovery` | Privileged Account Inventory | Inventario de cuentas privilegiadas — catálogo de todas las cuentas con acceso elevado (admin, root, service accounts con permisos amplios). Alimentado por escaneo periódico o registro manual | NIST AC-2(7) · CIS Controls v8 §5.1 · ISO 27001:2022 A.8.18 |
| B02 | `vaulting` | Credential Vaulting | Bóveda de credenciales privilegiadas — almacenamiento cifrado de contraseñas admin, claves SSH, certificados de servicio. Rotación automática post-uso. Integra con Vault | NIST IA-5(7) · CIS Controls v8 §5.3 · ISO 27001:2022 A.8.18 |
| B03 | `jit` | Just-in-Time Access (JIT) | Acceso JIT — provisionamiento de privilegio elevado solo cuando se necesita, con ventana temporal definida (15-60 min típico). Desaprovisionamiento automático al expirar | NIST AC-6(9) · CIS Controls v8 §5.4 · ISO 27001:2022 A.8.18 |
| B04 | `brokering` | Privileged Session Brokering | Brokering de sesión privilegiada — intermediación del acceso a sistemas críticos sin exponer credenciales directamente al usuario. Single Sign-On a sistemas protegidos | NIST AC-17(9) · ISO 27001:2022 A.5.18 · CyberArk/BeyondTrust patterns |
| B05 | `review` | Privilege Review | Revisión periódica de privilegios — ¿sigue siendo necesario este nivel de acceso? Campaña de recertificación específica para cuentas privilegiadas. Más frecuente que D01 `certification` | NIST AC-2(7) · ISO 27001:2022 A.8.2 · CIS Controls v8 §5.1 |
| B06 | `session_recording` | Session Recording | Grabación de sesión privilegiada — registro completo de comandos, pantallas, archivos transferidos durante una sesión admin. WORM. Mandatorio en muchas regulaciones financieras | NIST AU-14 · ISO 27001:2022 A.8.20 · PCI DSS 4.0.1 Req 8.6 |
| B07 | `zona_negocios` | Business Zone Registry | Contenedor de aplicaciones PAM. Prefijo `zona_pam_*`. Niveles: privileged_system / session_type / recording_policy | NGAC INCITS 565-2020 §4 · NIST AC-6(5) · CIS Controls v8 §5 |

**Átomos de referencia:**
```
d14.discovery.register          d14.discovery.scan          d14.discovery.audit
d14.vaulting.store              d14.vaulting.retrieve       d14.vaulting.rotate
d14.jit.request                 d14.jit.approve             d14.jit.revoke
d14.brokering.initiate          d14.brokering.terminate
d14.review.initiate             d14.review.approve          d14.review.report
d14.session_recording.start     d14.session_recording.stop  d14.session_recording.export
d14.zona_negocios.register
```

---

## 17. D15 — Identidad No Humana (NHI) (8 bloques)

**Propósito:** Identidad de entidades no humanas — service accounts, workloads (SPIFFE/SPIRE),
agentes IA, secretos de máquina, rotación automática, attestation, governance. El perímetro
de identidad se expande más allá de las personas.

**Pipeline:** POLICY-PATH + EXTERNAL-PATH — depende del tipo de entidad NHI.

**Normas principales:** SPIFFE Spec v1.0 · SPIRE v1.8 (2025) · CSA NHI Security Report 2025 ·
NIST SP 800-204A (microservices) · NIST AI RMF 1.0 · CIS Controls v8 §5.6 ·
NIST SP 800-57 Pt1 R5 (gestión de claves)

**Investigación 2025-2026:** CSA (Cloud Security Alliance) NHI Security Report 2025 establece
que las identidades no humanas superan en número a las humanas en una ratio 45:1 en empresas
enterprise. SPIFFE/SPIRE v1.8 (2025) es el estándar CNCF maduro para identidad de workload
— SVIDs (SPIFFE Verifiable Identity Documents) como la identidad portátil de un servicio.
NIST AI RMF 1.0 §3 establece el marco para gobernanza de sistemas IA — el bloque `agent`
implementa el principio de identidad verificable para agentes IA antes de otorgarles acceso.
NIST SP 800-57 Pt1 R5 §5.3 cubre gestión de claves criptográficas para máquinas — base del
bloque `secrets`. Gartner predice que para 2027, el 75% de los incidentes de seguridad
involucrará credenciales NHI comprometidas.

| Código | Slug canónico | Nombre BD | Descripción | Norma principal |
|--------|--------------|-----------|-------------|-----------------|
| B01 | `service_account` | Service Accounts | Cuentas de servicio — identidades para procesos, scripts, integraciones. Ciclo de vida completo: creación, permisos mínimos (least privilege), rotación, desactivación | NIST AC-2(9) · CIS Controls v8 §5.6 · ISO 27001:2022 A.5.16 |
| B02 | `workload` | Workload Identity | Identidad de workload basada en SPIFFE/SPIRE — SVID (X.509 o JWT) como identidad criptográficamente verificable de un servicio en tiempo de ejecución. mTLS entre servicios | SPIFFE Spec v1.0 §5 · SPIRE v1.8 · NIST SP 800-204A §3 |
| B03 | `agent` | AI Agent Identity | Identidad de agentes IA — verificación de identidad antes de otorgar acceso. Un agente IA debe tener identidad verificable, permisos mínimos y auditoría completa de sus acciones | NIST AI RMF 1.0 §3 · CSA NHI Security 2025 §4 · ISO/IEC 42001:2023 |
| B04 | `secrets` | Machine Secrets | Secretos de máquina — API keys, tokens de servicio, claves de cifrado para procesos automatizados. Almacenamiento en Vault con acceso auditado. No en variables de entorno | NIST SP 800-57 Pt1 R5 §5.3 · CIS Controls v8 §18.5 · OWASP ASVS v5 §6 |
| B05 | `rotation` | Automatic Rotation | Rotación automática de credenciales NHI — sin intervención humana. Frecuencia: secrets cada 30 días / certificados SVID cada 24h. Registro WORM de cada rotación | NIST SP 800-57 Pt1 R5 §5.3 · CIS Controls v8 §4.4 · NIST AC-2(2) |
| B06 | `attestation` | SPIFFE / SPIRE Attestation | Attestation de workload — verificación de que el proceso corriendo es quien dice ser (node attestor + workload attestor). Plugin-based: k8s, AWS, GCP, TPM | SPIFFE Spec v1.0 §8 · SPIRE v1.8 §4 · NIST SP 800-204A §4 |
| B07 | `governance` | NHI Identity Governance | Gobernanza de identidades no humanas — inventario completo, propietario responsable (human owner) por cada NHI, revisión periódica, offboarding cuando el servicio se retira | CSA NHI Security 2025 §4 · CIS Controls v8 §5 · NIST SP 800-53 R5.2 AC-2 |
| B08 | `zona_negocios` | Business Zone Registry | Contenedor de aplicaciones de identidad NHI. Prefijo `zona_nhi_*`. Niveles: identity_type / rotation_policy / attestation_method | NGAC INCITS 565-2020 §4 · SPIFFE Spec v1.0 · CIS Controls v8 §5.4 |

**Átomos de referencia:**
```
d15.service_account.create      d15.service_account.revoke  d15.service_account.audit
d15.workload.register           d15.workload.validate       d15.workload.rotate
d15.agent.register              d15.agent.validate          d15.agent.audit
d15.secrets.store               d15.secrets.retrieve        d15.secrets.rotate
d15.rotation.execute            d15.rotation.audit
d15.attestation.validate        d15.attestation.configure
d15.governance.review           d15.governance.report
d15.zona_negocios.register
```

---

## 18. D98 — Registro Estructural (4 bloques)

**Propósito:** Metaregistro del sistema — esquema de atributos, catálogo de átomos,
control de versiones del árbol de políticas, zona de negocio estructural.
Es el "registro de registros" de bAuth — define qué existe en el sistema.

**Pipeline:** ADMIN-PATH — solo accesible por roles SU/SYS.

**Normas principales:** ISO/IEC 24760-1:2019 · ISO 9001:2015 §7.5 ·
SCIM 2.0 RFC 7643 §4 · NIST SP 800-162 §4.2

**Investigación 2025-2026:** ISO/IEC 24760-2:2025 actualiza la arquitectura de referencia de
identidad — el esquema de atributos de D98 debe reflejar el modelo de "identity attributes"
vs "identity characteristics" de la norma. NIST SP 800-162 §4.2 (ABAC Guide) establece
que el catálogo de atributos (D98 B02) es la fuente de verdad para el motor ABAC — sin
catálogo mantenido, el PDP no puede operar. ISO 9001:2015 §7.5 (información documentada)
es la base normativa para el control de versiones del árbol.

| Código | Slug canónico | Nombre BD | Descripción | Norma principal |
|--------|--------------|-----------|-------------|-----------------|
| B01 | `schema` | Attribute Schema | Esquema de atributos del sistema — catálogo de todos los atributos posibles de una entidad, sus tipos, validaciones y restricciones. Base del motor ABAC | SCIM 2.0 RFC 7643 §4 · ISO/IEC 24760-1:2019 §5 · NIST SP 800-162 §4 |
| B02 | `catalog` | Atom Catalog | Catálogo de átomos — registro de todos los átomos definidos en el sistema con su namespace, descripción, dominio y estado. Fuente de verdad del PDP | NIST SP 800-162 §4.2 · ISO/IEC 24760-2:2025 §7 |
| B03 | `versioning` | Tree Version Control | Control de versiones del árbol de políticas — cada cambio en `idn_roles_template` genera una versión. Permite rollback y auditoría de cambios estructurales | ISO 9001:2015 §7.5 · ISO/IEC 24760-2:2025 §7 |
| B04 | `zona_negocios` | Business Zone Registry | Zona estructural del registro — `zona_diag_*`. Define zonas de diagnóstico y mantenimiento del propio sistema bAuth | ISO/IEC 24760-2:2025 §6 · NIST SP 800-162 §4 |

**Átomos de referencia:**
```
d98.schema.read                 d98.schema.configure
d98.catalog.read                d98.catalog.register        d98.catalog.deprecate
d98.versioning.read             d98.versioning.rollback
d98.zona_negocios.register
```

---

## 19. D99 — Administración Global (7 bloques)

**Propósito:** Administración global del sistema — usuarios del sistema, notificaciones
globales, excepciones HITL, parámetros criptográficos, mapa de conformidad regulatoria,
cadena de suministro de software (SBOM). Dominio transversal de gobernanza.

**Pipeline:** ADMIN-PATH — solo accesible por roles SU/SYS global.

**Normas principales:** NIST SP 800-53 R5.2 AC-2 · ISO 27001:2022 A.5.16 ·
NIST SP 800-131A R2 · ISO 19600:2014 · NTIA SBOM 2021 · NIST AI RMF 1.0

**Investigación 2025-2026:** NIST SP 800-131A R2 (2019, vigente) establece los algoritmos
criptográficos aprobados — el bloque `cryptography` debe alinearse a la transición
post-cuántica (PQC): NIST FIPS 203 (ML-KEM), FIPS 204 (ML-DSA), FIPS 205 (SLH-DSA)
publicados en agosto 2024 — la primera ola de estándares PQC. NTIA SBOM 2021 define el
formato mínimo de SBOM — el bloque `supply_chain` implementa este requisito. EO 14028
(Executive Order on Improving the Nation's Cybersecurity, mayo 2021) hace el SBOM
obligatorio para proveedores del gobierno estadounidense — relevante para exportaciones SBOS.
ISO 19600:2014 (Compliance Management) es la base del bloque `compliance`.

| Código | Slug canónico | Nombre BD | Descripción | Norma principal |
|--------|--------------|-----------|-------------|-----------------|
| B01 | `users` | Global Users | Usuarios globales del sistema — cuentas SU/SYS que trascienden tenants. Gestión centralizada de administradores globales. Revisión trimestral obligatoria | NIST AC-2 · ISO 27001:2022 A.5.16 · CIS Controls v8 §5 |
| B02 | `notifications` | Global Notifications | Notificaciones globales del sistema — alertas de seguridad, cambios de política, incidentes. Integra con bNotify. Multi-canal (email, push, SIEM) | NIST SI-12 · ISO 27001:2022 A.5.2 |
| B03 | `exceptions` | HITL Exceptions | Excepciones Human-in-the-Loop — casos que el sistema no puede resolver automáticamente y requieren decisión humana. Protocolo de escalada. NIST AI RMF 1.0 §3.6 | NIST AI RMF 1.0 §3.6 · ISO 27001:2022 A.5.29 |
| B04 | `cryptography` | Cryptographic Parameters | Parámetros criptográficos globales — algoritmos aprobados, longitudes de clave, períodos de validez. Post-cuántica: FIPS 203/204/205 (PQC, agosto 2024) | NIST SP 800-131A R2 · NIST FIPS 203/204/205 (PQC 2024) · ISO 27001:2022 A.8.24 |
| B05 | `compliance` | Compliance Map | Mapa de conformidad regulatoria — qué normas aplican al sistema, su estado de cumplimiento, evidencias. SOC 2, ISO 27001, PCI DSS, Ley 1174 Bolivia | ISO 19600:2014 §6 · NIST CA-2 · ISO 27001:2022 A.5.36 |
| B06 | `supply_chain` | SBOM Supply Chain | Software Bill of Materials (SBOM) — inventario de todos los componentes de software del sistema, sus versiones y vulnerabilidades conocidas. Formato SPDX o CycloneDX | NTIA SBOM 2021 · NIST SP 800-53 R5.2 SA-12 · EO 14028 |
| B07 | `zona_negocios` | Business Zone Registry | Zona administrativa global — `zona_admin_*`. Define zonas de administración central del ecosistema SBOS | ISO 9001:2015 §5.1 · NIST SP 800-53 R5.2 PL-2 |

**Átomos de referencia:**
```
d99.users.create                d99.users.revoke            d99.users.audit
d99.notifications.emit          d99.notifications.configure
d99.exceptions.create           d99.exceptions.resolve      d99.exceptions.audit
d99.cryptography.configure      d99.cryptography.audit
d99.compliance.read             d99.compliance.update       d99.compliance.report
d99.supply_chain.publish        d99.supply_chain.validate
d99.zona_negocios.register
```

---

## 20. Discrepancias resueltas

Dos discrepancias detectadas entre A.65.03 (investigación) y la BD (SSOT):

| Dominio | Bloque | A.65.03 | BD (SSOT adoptado) | Resolución |
|---------|--------|---------|-------------------|------------|
| D10 Delegación | B03 | `restrictions` | `sod_validation` | La BD es más precisa: el bloque valida específicamente SoD antes de delegar. Las restricciones genéricas están implícitas en los demás bloques. Slug canónico: **`sod_validation`** |
| D14 PAM | B01 | `discovery` | `Privileged Account Inventory` | La BD define el alcance correcto: bAuth mantiene un inventario, no es un scanner de red. El descubrimiento activo es responsabilidad de herramientas externas. Slug canónico: **`discovery`** (mantenido por semántica PAM estándar, nombre descriptivo: Privileged Account Inventory) |

---

## 21. Resumen de bloques por dominio

| Dominio | Código | Bloques | B01–B03 | B04–B06 | B07+ |
|---------|--------|---------|---------|---------|------|
| Identidad Organizacional | D00 | 9 | rol_esquema · rol_entidad · usuario_esquema | usuario_entidad · atributos · proofing | consentimiento · verifiable_credential · fal |
| Control de Acceso Lógico | D01 | 9 | authorization · roles · zones | fields · contracts · session | certification · dynamic_policy · zona_negocios |
| Control de Acceso Físico | D02 | 8 | facilities · readers · presence | antipassback · visitors · emergency | mustering · zona_negocios |
| Controles Financieros | D03 | 9 | limits · approvals · segregation | billing · reporting · fraud | reconciliation · open_banking · zona_negocios |
| Acceso Temporal | D04 | 6 | windows · periods · calendar | schedules · exceptions · zona_negocios | — |
| Autenticación Biométrica | D05 | 7 | enrollment · verification · liveness | identification · quality · revocation | zona_negocios |
| Acceso Geoespacial | D06 | 6 | geofencing · location · velocity | residency · fleet · zona_negocios | — |
| Seguridad de Red | D07 | 8 | connection · tokens · rate | posture · segmentation · inspection | propagation · zona_negocios |
| Contexto / Sesión | D08 | 7 | session · risk · device | emergency · assurance · itdr | zona_negocios |
| Gestión de Credenciales | D09 | 10 | password · mfa · certificates | tokens · revocation · recovery | binding · passkey · introspection · zona_negocios |
| Delegación e Impersonación | D10 | 7 | delegation · renewal · sod_validation | chain · audit · rich_authorization | zona_negocios |
| Auditoría y Cumplimiento | D11 | 7 | events · retention · integrity | monitoring · export · review | zona_negocios |
| Anclaje Blockchain | D12 | 7 | anchoring · transactions · wallet | merkle · did · consensus | zona_negocios |
| Firma Digital Externa | D13 | 8 | signing · certification · timestamping | verification · revocation · long_term | eudi_wallet · zona_negocios |
| Gestión de Acceso Privilegiado | D14 | 7 | discovery · vaulting · jit | brokering · review · session_recording | zona_negocios |
| Identidad No Humana (NHI) | D15 | 8 | service_account · workload · agent | secrets · rotation · attestation | governance · zona_negocios |
| Registro Estructural | D98 | 4 | schema · catalog · versioning | zona_negocios | — |
| Administración Global | D99 | 7 | users · notifications · exceptions | cryptography · compliance · supply_chain | zona_negocios |
| **TOTAL** | **18** | **134** | **54** | **52** | **28** |

---

## 22. Estado de implementación global

| Indicador | Valor |
|-----------|-------|
| Dominios | 18 (D00–D15, D98, D99) |
| Bloques totales | 134 |
| Bloques a depth=2 (nodo presente) | 134 (100%) |
| Bloques con átomos a depth≥3 | 0 (0%) |
| Trabajo pendiente | Insertar políticas/átomos en TODOS los 134 bloques |
| Único dominio con B10 | D09 (Gestión de Credenciales) |
| Dominios con B09 | D00, D01, D03, D09 |
| Dominios con solo hasta B06 | D04, D06 |
| Dominio con menos bloques | D98 (4 bloques) |
| Dominio con más bloques | D09 (10 bloques) |

**Próximo paso:** Diseñar e insertar los átomos (depth=3) para cada bloque, comenzando
por los dominios del pipeline Fast-Path (D01, D02) que son bloqueantes para el BitMask.

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-28 | Versión inicial. Formalización completa de los 134 bloques en 18 dominios. SSOT: BD VPS SBOSDB verificada 2026-07-28. Base: A.65.03 v1.6.0 + investigación normativa 2024–2026. Discrepancias D10-B03 y D14-B01 resueltas. |
