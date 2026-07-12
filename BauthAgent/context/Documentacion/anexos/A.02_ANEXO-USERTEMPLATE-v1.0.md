# Anexo A.02 — El Contrato UserTemplate v6.0
## Documento de respaldo: la identidad digital completa del actor — estructura, origen normativo y verificación de completitud

**Tipo:** ANEXO — documento de respaldo del corpus (los manuales afirman, este anexo respalda)
**Versión del anexo:** 1.1.0 · **Fecha:** 2026-07-11
**Estatus:** FUENTE AUTOSUFICIENTE — contiene la estructura COMPLETA del contrato (traslado fiel, §22); la documentación de origen queda como cita histórica y **no es fuente de lectura**
**Respalda a:** MANUAL-USER-TEMPLATE (1.08) §3-§10 · MANUAL-MOTOR-VERSIONADO (1.13 — F5) · MANUAL-AUTENTICACION (2.01) · MANUAL-SEGURIDAD-DATOS (2.10)
**Fuentes de origen (cita histórica):** `SBOS-USERTEMPLATE-v6_0` (contrato definitivo, jun-2026) · verificación contra fuentes primarias 2026-07-11
**Normas base:** SCIM 2.0 RFC 7643 (§4.1 Core · §4.3 Enterprise) · NIST SP 800-63A (IAL) · NIST SP 800-63B (AAL §4-5 · sesiones §7 · reauth §9) · OIDC Core 1.0 · ANSI INCITS 359 (`USERS`/`UA`) · RGPD Arts. 4/9/17/46 · ISO/IEC 27701 · ISO 24760 · FIDO2/WebAuthn W3C · SIA OSDP v2.2.2 · ISO/IEC 30107-3 · NIST SP 800-124

---

## Tabla de contenidos

1. [Propósito del anexo y cómo citarlo](#1-propósito-del-anexo-y-cómo-citarlo)
2. [El contrato en una vista — identidad vs autoridad](#2-el-contrato-en-una-vista--identidad-vs-autoridad)
3. [B1 — Identificación y metadatos](#3-b1--identificación-y-metadatos)
4. [B2 — Información personal (PII)](#4-b2--información-personal-pii)
5. [B3 — Información profesional](#5-b3--información-profesional)
6. [B4 — Rol asignado (UA)](#6-b4--rol-asignado-ua)
7. [B5 — Credenciales digitales registradas](#7-b5--credenciales-digitales-registradas)
8. [B6 — Credenciales físicas](#8-b6--credenciales-físicas)
9. [B7 — Binding con sistemas](#9-b7--binding-con-sistemas)
10. [B8 — Preferencias de UI](#10-b8--preferencias-de-ui)
11. [B9 — Cumplimiento territorial y normativo](#11-b9--cumplimiento-territorial-y-normativo)
12. [B10 — Persistencia y sesiones](#12-b10--persistencia-y-sesiones)
13. [B11 — Gestión de dispositivos](#13-b11--gestión-de-dispositivos)
14. [B12 — Cumplimiento y capacitación](#14-b12--cumplimiento-y-capacitación)
15. [B13 — Perfiles de seguridad y comportamiento](#15-b13--perfiles-de-seguridad-y-comportamiento)
16. [B14 — Acceso contextual (excepciones individuales)](#16-b14--acceso-contextual-excepciones-individuales)
17. [B15 — Integraciones con sistemas externos](#17-b15--integraciones-con-sistemas-externos)
18. [B16 — Auditoría y estado de sincronización](#18-b16--auditoría-y-estado-de-sincronización)
19. [Verificación de completitud — dominios del sujeto y resoluciones U1–U7](#19-verificación-de-completitud--dominios-del-sujeto-y-defases-u1u7)
20. [Validaciones, PII e invariantes](#20-validaciones-pii-e-invariantes)
21. [El ciclo JML del contrato](#21-el-ciclo-jml-del-contrato)
22. [Traslado fiel — la estructura JSONB completa](#22-traslado-fiel--la-estructura-jsonb-completa-del-contrato-v60)
23. [Mapa anexo → manuales](#23-mapa-anexo--manuales)
24. [Referencias e historial](#24-referencias-e-historial)

---

## 1. Propósito del anexo y cómo citarlo

Este anexo es el respaldo documental estructurado del contrato UserTemplate: (a) la estructura
completa de sus 16 bloques trasladada fielmente (§22), (b) la lectura normativa a nivel de
campo por bloque (§3–§18), y (c) la **verificación de completitud contra las normas y los
estándares** (§19) con los defases detectados para decisión HITL.

**Cómo citarlo:** `A.02 §B5` (un bloque) · `A.02 §19 U1` (un defase) · `A.02 §20` (validaciones).

**Frontera con los manuales:** la doctrina de identidad (identidad-vs-autoridad, JML, PII,
invariantes como principios) vive en MANUAL-USER-TEMPLATE (1.08) — aquí se respalda con el
detalle de campo y el artefacto íntegro, sin re-explicarla.

**Materialización vigente (ADR-010 — resuelta y documentada por los manuales):** bAuth es
**autosuficiente** — motor de autenticación nativo con 9 métodos, JWT propio, OIDC Provider
nativo y framework declarativo de 7 tablas (MANUAL-AUTENTICACION 2.01 §3-§7 y §11); JML
soberano (MANUAL-USER-TEMPLATE 1.08 §7). **Las lecturas §3–§18 describen esa materialización
vigente.** Los nombres y destinos de época del contrato v6.0 (`keycloak_*`, `kc_*`, bindings a
motores eliminados) aparecen únicamente dentro del traslado fiel (§22) — el artefacto
histórico conservado tal cual — con su equivalencia nativa declarada en la lectura de cada
bloque.

---

## 2. El contrato en una vista — identidad vs autoridad

La separación crítica del contrato (la división normada `USERS` ↔ `ROLES` — INCITS 359;
doctrina en 1.08 §2):

| Dimensión | UserTemplate (este anexo) | RolTemplate (A.01) |
|---|---|---|
| Pregunta | ¿QUIÉN es este usuario? | ¿QUÉ puede hacer este tipo de rol? |
| Permisos | **Hereda** del RolTemplate asignado — JAMÁS propios (invariante 4) | Los define |
| Autenticación | Registra qué métodos **TIENE** | Define qué métodos son **REQUERIDOS** |
| Horario | Excepciones individuales aprobadas | El horario base |
| Biometría | El hash del individuo (con consentimiento) | La política de enrolamiento |
| Multiplicidad | Un UserTemplate → UN usuario | Un RolTemplate → muchos usuarios |

**Materialización actual:** tabla `bauth.idn_user_template` (26 columnas + contrato JSONB —
1.08 §3) · asignación en `idn_user_role` (1.08 §5) · 15 secciones validadas por
`usertemplate_validator.rs` (la cuenta 15-vs-16: el bloque de sincronización/BitMask vive en
columnas — 1.08 §4).

---

## 3. B1 — Identificación y metadatos

**Propósito:** identidad canónica inmutable. **Estándar:** SCIM RFC 7643 §4.1 · ISO 24760-1 §5.

| Parte | Qué define | Norma · estado |
|---|---|---|
| `id` | ID interno autoincremental — solo joins | — |
| `uuid` | Identificador global **INMUTABLE** — el `sub` del JWT; persiste tras el offboarding (auditoría histórica) | SCIM `id` · ISO 24760 (persistente). El contrato dice "UUID v4" — **resuelto U4 (§19.2): la convención vigente es `uuidv7()`** (G-B01-01, RFC 9562) |
| `external_id` | ID en el sistema de RRHH — sincronización SCIM bidireccional | SCIM `externalId` |
| `username` | Canónico `{nombre}.{apellido}` · único por tenant · inmutable | SCIM `userName` |
| `tenant_id` / `empresa_id` | Tenant + empresa (multi-empresa) — capas 1-2 del modelo de contexto | Multi-tenancy (1.12) |
| `version` | SemVer del contrato de ESTE usuario | El motor 1.13 la gobierna (F5) |
| `status` | `ACTIVE / INACTIVE / SUSPENDED / TERMINATED / PENDING` | NIST AC-2 (estados de cuenta) |
| `account_type` | `HUMAN / SERVICE / SYSTEM / GUEST` — SERVICE jamás MFA/biométrico | NIST AC-2(a) · alineado al catálogo `idn_role_type` (A.01 §B1) |
| `digital_signature` | Firma del contrato de identidad: algoritmo, huella del certificado, validez | Integridad del artefacto. El contrato usa `"CRYSTALS-Dilithium"` — **resuelto U2 (§19.2): EdDSA Ed25519 + post-cuántico ML-DSA (FIPS 204)**, alineado al rol y al catálogo `crypto_algorithm` (2.01 §7) |

**Verificación de completitud — U1 (§19.2):** B1/B2 no registraban el IAL del sujeto (a qué
nivel fue verificada su identidad, con qué evidencia — NIST SP 800-63A). **Resuelto con la
especificación `identity_proofing`** (§19.2-U1).

---

## 4. B2 — Información personal (PII)

**Propósito:** datos personales — régimen reforzado. **Estándar:** SCIM §4.1.2 · OIDC claims ·
RGPD.

| Parte | Qué define | Norma |
|---|---|---|
| `_classification` | `CONFIDENTIAL` — controla acceso y enmascaramiento (sin LoA 3 ningún rol operativo ve todo) | ISO A.5.12 · 2.10 §5 |
| `basic` | Claims OIDC literales: `given_name`, `family_name` (+segundo apellido LatAm), `name`, `birth_date` (ISO 8601, solo RRHH), `gender` (dato sensible), `nationality` (ISO 3166-1), `national_id` **siempre enmascarado** + tipo (CI/DNI/PASSPORT…), `locale` (BCP 47), `zoneinfo` (IANA) | OIDC Core · RGPD Art. 9 |
| `contact.emails[]` | Por dirección: tipo (work/recovery), primaria, **verificada + método + fecha** — el email de recuperación con `purpose` explícito | 800-63B (verificación de canal) |
| `contact.phones[]` | Por número: tipo, verificado, país, `purpose` — **resuelto U5 (§19.2): `sms_otp` se retira de los propósitos** (deprecado por 800-63B Rev.4; el catálogo declarativo `auth_method.nist_status` lo gobierna — 2.01 §7) | 800-63B §5.1.3 |
| `addresses[]` | Con coordenadas y exactitud — la dirección de trabajo referencia la zona física | SCIM `addresses` |
| `emergency_contacts[]` | Contactos con canales de notificación | — |

Los campos 1:N (emails, phones, addresses) se materializan en `idn_atributo` — regla de
almacenamiento de 1.08 §3.

---

## 5. B3 — Información profesional

**Propósito:** datos laborales. **Estándar:** **SCIM Enterprise Extension RFC 7643 §4.3 —
verificado atributo por atributo** (1.08 §4.1).

| Parte | Qué define | Norma |
|---|---|---|
| `employee_code`, `department`, `division`, `cost_center` | Atributos LITERALES del RFC (`employeeNumber`, `department`, `division`, `costCenter`) | RFC 7643 §4.3 |
| `job_title` (+en), `employment_type` (FULL_TIME/PART_TIME/CONTRACTOR/INTERN/GUEST), `employment_status`, `hire_date`/`termination_date` | El ciclo laboral que dispara el JML (§21) | SCIM · JML (1.08 §7) |
| `manager_uuid`/`manager_username` | El `manager` del RFC — referencia jerárquica | RFC 7643 §4.3 `manager` |
| `office_location` | Edificio/piso/escritorio + `zone_id` — ancla al árbol físico | D2 (OSDP) |
| `reporting_line`, `certifications[]` | Cadena de reporte · certificaciones profesionales verificables con expiración | ISO A.6.3 |

---

## 6. B4 — Rol asignado (UA)

**Propósito:** la relación formal usuario→rol — el conjunto `UA` del estándar RBAC.
**Estándar:** INCITS 359 §4.2 (User-Role Assignment).

| Parte | Qué define | Norma · detalle |
|---|---|---|
| `active_roles[]` | Por asignación: `role_id` + **quién asignó y quién aprobó** (dual) + vigencia (`valid_from/until`; `null` hereda la del rol) + `assignment_reason` documentada | AC-2 · AC-5 · materializada en `idn_user_role` (1.08 §5) |
| `active_roles[].context_overrides` | Excepciones individuales al rol (temporales/red) **con aprobador y razón** — el espejo operativo de B14 | AC-5 (excepción documentada) |
| `history[]` | Asignaciones pasadas con `removed_at/by`, razón (`PROMOTION`…) y documentación — el rastro JML | AU-3 · ISO 24760 §7 |
| `temporary_assignments[]` | **Delegaciones RECIBIDAS**: origen (usuario/rol), vigencia, `delegated_permissions[]` (solo los delegables según el `delegation_config` del rol origen — A.01 §B10), `restricted_permissions[]` explícitos, aprobador, `auto_revoke`, estado (SCHEDULED/ACTIVE/EXPIRED/REVOKED) | INCITS 359 DSD — la contraparte del sujeto |

---

## 7. B5 — Credenciales digitales registradas

**Propósito:** qué métodos TIENE el usuario (los requisitos viven en el rol — la separación
formal de 800-63B). **Estándar:** FIDO2/WebAuthn W3C · RFC 6238 · NIST 800-63B §5.
**Materialización vigente (nativa — resuelto U7, §19.2):** el registro de autenticadores del
sujeto vive en las tablas nativas del framework (`ath_mfa_enrollment`, `ath_binding`,
`ath_password_history` y familia `ath_*`), gobernado por el catálogo declarativo `auth_method`
(`aal_level` + `nist_status` por método — 2.01 §7). El nombre `keycloak_credentials` y los
campos `kc_*` pertenecen al artefacto de época y solo aparecen en el traslado (§22).

| Parte | Qué define | Norma |
|---|---|---|
| `has_password` + metadatos | Cambio/expiración/**fortaleza mínima 80 (zxcvbn)** — el hash JAMÁS aquí (invariante 2) | 800-63B §5.1.1 |
| `totp_devices[]` | Por dispositivo: nombre, registro, último uso, credential_id | RFC 6238 |
| `webauthn_credentials[]` | Por credencial: tipo (security_key/platform_biometric/passkey), **AAGUID** (modelo del autenticador), **attestation verificada**, `user_verification: required` | W3C WebAuthn L3 · FIDO2 |
| `has_x509_smartcard` / `has_passkey` / `has_email_otp` | Flags del pool restante | 800-63B |
| `backup_codes` | Generación, restantes, agotamiento | 800-63B §5.1.2 |
| `credentials_compliance` | **El puente TIENE↔REQUIERE**: ¿las credenciales cubren los `requiredMethods` del rol? + faltantes + fecha de chequeo | La validación de cobertura (§20) |

---

## 8. B6 — Credenciales físicas

**Propósito:** credenciales de acceso presencial del sujeto. **Estándar:** SIA OSDP v2.2.2 ·
ISO/IEC 14443 · ISO/IEC 30107-3.

| Parte | Qué define | Norma |
|---|---|---|
| `smart_cards[]` | Por tarjeta: tipo (DESFire), número **enmascarado**, facility code, estado, expiración, último uso/zona, **versión de la clave AES en la bóveda** | ISO 14443 · OSDP |
| `mobile_credentials[]` | Credenciales móviles (BLE) por dispositivo | OSDP |
| `biometric_templates[]` | **Solo hashes, jamás el biométrico crudo** (invariante 1): tipo/dedo, hash+algoritmo+iteraciones, política de enrolamiento, **liveness verificado**, verificación del admin, FMR logrado, lector, **consentimiento explícito con fecha** (RGPD Art. 9), revocación | ISO 30107-3 · NIST 800-76-2 · RGPD Art. 9. **Resuelto U3 (§19.2): la política vigente es Argon2id** (parámetros por tier ya declarados en `auth_config.hash.argon2id.params` — 2.01 §7.4); los templates PBKDF2 del artefacto migran por re-enrolamiento |
| `qr_config` | QR dinámico: TTL 30 s, **versión de la clave HMAC en la bóveda (rotada cada 90 días)** | HMAC-SHA256 |

---

## 9. B7 — Binding con sistemas

**Propósito:** vinculación del sujeto con las aplicaciones del ecosistema — el propósito de
SCIM. **Estándar:** RFC 7643/7644. **Materialización vigente:** la integración de datos con
las aplicaciones pasa por **biedata** (la aduana de datos JSON-RPC del ecosistema — así lo
documenta el JML soberano: "RRHH → biedata → bAuth", 1.08 §7); el patrón del bloque (IDs
cruzados + estado + última sincronización por sistema) es el registro vigente de ese
provisioning. Los destinos nominales del artefacto son de época (solo en §22).

| Parte | Qué define |
|---|---|
| Por sistema | IDs del usuario en el destino (user/employee/party), estado activo, grupos/roles del destino, `last_synced_at` |

---

## 10. B8 — Preferencias de UI

**Propósito:** personalización — **declarado sin impacto de seguridad** (el contrato distingue
lo normado de lo que no lo es — 1.08 §4).

| Parte | Qué define |
|---|---|
| `theme` | Modo, esquema, tamaño de fuente + **accesibilidad** (alto contraste, reducción de movimiento, lector de pantalla) |
| `layout` / `notifications` / `language` | Widgets, vistas por defecto · canales + horario de silencio · idioma/formatos (BCP 47, formato boliviano de números) |

---

## 11. B9 — Cumplimiento territorial y normativo

**Propósito:** las restricciones legales del país del sujeto. **Estándar:** RGPD Art. 46 ·
eIDAS · ISO 27701.

| Parte | Qué define | Norma |
|---|---|---|
| `primary_jurisdiction` + `applicable_regulations[]` | Jurisdicción ISO 3166 + regulaciones activas (protección de datos BO, Ley 843, SIAT) — activan el control normativo del contexto | Ley 843 · SIN |
| `data_residency` | Residencia del dato personal/financiero (BO) y del backup (LATAM) — soberanía del dato | RGPD Art. 46 · 2.10 §1 |
| `geo_restrictions` | Países de acceso permitidos, bloqueos, **VPN obligatoria desde el exterior** | D6 del sujeto |
| `privacy` | **Consentimiento con versión de política y fecha** · `data_processing_basis` (las 6 bases legales del RGPD) · **el estado de los derechos ARCO-P del titular** (acceso/portabilidad/borrado/restricción) | RGPD Arts. 6/7/15-21 |

---

## 12. B10 — Persistencia y sesiones

**Propósito:** el ciclo de vida de sesiones del sujeto — la estructura exacta de 800-63B §7.
**Estándar:** NIST 800-63B §7 · OWASP Session Management.

| Parte | Qué define | Norma |
|---|---|---|
| `session_tracking.current_session` | Sesión viva: dispositivo, IP, nodo, **nivel de autenticación + estado MFA + método + `loa_achieved` + `acr_value`** — el AAL es propiedad de la SESIÓN (verificado: así lo define el estándar) | 800-63B §4/§7 |
| `session_tracking.history` | Último login exitoso/fallido, fallos del día, sesiones 30d | AU-3 |
| `token_management` | Access (JWT, TTL 60 min, ventana de renovación) · refresh (opaco, 7 días, **single_use con rotación**) | OAuth 2.0 BCP · 2.03 |
| `device_trust.trusted_devices[]` | Por dispositivo: **trust_score**, nivel, verificación, estado de cumplimiento | D8/ITDR |

---

## 13. B11 — Gestión de dispositivos

**Propósito:** los dispositivos del sujeto y su postura. **Estándar:** NIST SP 800-124 · MDM.

| Parte | Qué define |
|---|---|
| `registered_devices[]` | Por dispositivo: identidad completa (serial **enmascarado**, asset tag), `ownership` (CORPORATE/BYOD), MDM, **agente de dispositivo instalado** (con verificación de integridad), `security_status` (cifrado, antivirus, firewall, parches, TPM 2.0, secure boot / en móvil: bloqueo biométrico, jailbreak), `compliance_level`, `trust_score`, certificado del dispositivo |
| `trusted_networks[]` | Redes de confianza con rangos, nivel, certificado requerido, zona |
| `vpn_configurations[]` | Perfil VPN: IKEv2/IPSec, autenticación (certificado+TOTP), AES-256-GCM, **split_tunnel: false** (todo el tráfico por VPN) |

Es la contraparte del sujeto del plano D7 (el rol define la política de red — A.01 §17.2-B16;
el usuario porta los dispositivos y su postura).

---

## 14. B12 — Cumplimiento y capacitación

**Propósito:** la competencia del sujeto. **Estándar:** ISO A.6.3 · PCI Req 12.6.

| Parte | Qué define |
|---|---|
| `certifications_status[]` | Certificaciones de seguridad con estado/vigencia y **`blocking: true`** — sin la certificación bloqueante el usuario NO puede estar ACTIVE (validación §20) |
| `training_status` | Cursos completados (con score y vigencia) y pendientes (con due date y obligatoriedad) |
| `policy_acknowledgments[]` | Reconocimiento de políticas **por versión** con método (firma electrónica) — evidencia de A.6.3 |

---

## 15. B13 — Perfiles de seguridad y comportamiento

**Propósito:** el riesgo dinámico del sujeto (ITDR) — actualizado en tiempo real.
**Estándar:** NIST 800-63B §9 (reauth) · patrones UEBA · NIST 800-207 §4.

| Parte | Qué define |
|---|---|
| `risk_score` | Score global 0.0-1.0 **calculado continuamente** + desglose por componente (autenticación, dispositivo, comportamiento, ubicación, cumplimiento) + nivel (LOW→CRITICAL) + tendencia |
| `behavior_analytics` | Baseline conductual (30 días): patrones de login (horario/dispositivo/ubicación con frecuencia), anomalías, **dinámica de tecleo (solo confianza — el template hash vive en la BD del daemon, jamás aquí)** |
| `security_incidents[]` | Historial de incidentes del sujeto |
| `mfa_compliance` | Cumplimiento MFA vivo: fallos consecutivos, lockout activo/hasta | 

Alimenta el plano D8 (el rol define los umbrales — A.01 §17.2-B17; el usuario porta las señales).

---

## 16. B14 — Acceso contextual (excepciones individuales)

**Propósito:** sobrescrituras individuales al rol — raramente usadas, **toda excepción con
aprobación documentada** (AC-5). Tres familias: `location_exceptions[]` (redes adicionales con
aprobador, vigencia y razón), `temporal_exceptions[]`, `device_exceptions[]`. El rol define la
base; esto es ADICIONAL, temporal y auditado.

---

## 17. B15 — Integraciones con sistemas externos

**Propósito:** el estado de integración (RRHH driver del JML, federación, directorio).
**Materialización vigente:** el RRHH como **fuente autoritativa** de los eventos JML llega vía
biedata (1.08 §7); la federación/SSO la provee el **OIDC Provider nativo** de bAuth (2.01 §11)
y los protocolos del catálogo `federation_protocol` (2.01 §7); el MFA es nativo (TOTP/WebAuthn
— 2.01 §4). El patrón del bloque (por integración: proveedor + estado + última sincronización
+ campos) es el registro vigente; los proveedores nominales del artefacto son de época (§22).

---

## 18. B16 — Auditoría y estado de sincronización

**Propósito:** trazabilidad del artefacto + coherencia declarado↔real — **READONLY del daemon**
(jamás versión humana — 1.13 P9).

| Parte | Qué define |
|---|---|
| `audit` | created/updated by+at · hitos JML: `onboarding_completed_at`, `offboarding_started/completed_at` |
| `sync_state` | `sync_status` (PENDING/SYNCING/SYNCED/ERROR/DRIFT) — **vigente: coherencia interna** (BitMask + validador + políticas); la "sincronización" a destinos externos sobrevive **solo como prueba de consistencia opcional** (nota canónica de 1.08 §7.2); los destinos nominales, en §22 |

Nota 15-vs-16: el validador verifica 15 secciones JSONB; este B16 vive parcialmente en
columnas (`sync_status`, `rol_bitmask_base64`) — ambas cuentas correctas (1.08 §4).

---

## 19. Verificación de completitud — dominios del sujeto y resoluciones U1–U7

### 19.1 La cobertura por dominios (D00–D13 proyectados sobre la IDENTIDAD)

El principio: el ROL define la política de cada plano; el USUARIO porta lo que el plano
necesita del SUJETO (credenciales, señales, excepciones, consentimientos). Matriz contra la
taxonomía canónica (1.01 §4):

| Plano | Qué necesita del sujeto | Dónde vive en el contrato | Estado |
|---|---|---|:---:|
| **D00** Organizacional | Identidad canónica + posición | B1 + B3 (SCIM Core+Enterprise) | ✅ |
| **D1** Lógico | Los autenticadores que TIENE + cobertura de requisitos | B5 (+`credentials_compliance`) | ✅ (U7 resuelto: materialización nativa `ath_*`) |
| **D2** Físico | Tarjetas, móviles, QR | B6 | ✅ |
| **D3** Financiero | **Nada propio** — límites y aprobaciones son del rol (invariante 4: permisos jamás en el usuario) | N/A por diseño | ✅ por diseño |
| **D4** Temporal | Excepciones horarias individuales aprobadas | B4 `context_overrides` + B14 | ✅ |
| **D5** Biométrico | Templates (hash) + consentimiento Art. 9 + liveness | B6 `biometric_templates` | ✅ (U3 resuelto: Argon2id por re-enrolamiento) |
| **D6** Geoespacial | Jurisdicción, países permitidos, excepciones de ubicación | B9 + B14 | ✅ |
| **D7** Red | Dispositivos con postura, redes de confianza, VPN | B11 | ✅ |
| **D8** Contexto/Sesión | Riesgo vivo, baseline conductual, sesión con LoA/ACR | B13 + B10 | ✅ |
| **D9** Credenciales | El registro completo de autenticadores + backup + recuperación **+ el IAL del proofing (U1)** | B5 + B6 + B2 + `identity_proofing` (§19.2-U1) | ✅ con U1 |
| **D10** Delegación | Delegaciones RECIBIDAS con restricciones | B4 `temporary_assignments` | ✅ |
| **D11** Auditoría | Rastro del artefacto + hitos JML + reconocimientos | B16 + B12 | ✅ |
| **D12** Blockchain | **Wallet del sujeto** (address, custodia en bóveda) | `legal_signature_identity` (§19.2-U6) | ✅ con U6 |
| **D13** Firma legal | **Certificado ADSIB del sujeto** — la firma jurídica la ejerce una PERSONA | `legal_signature_identity` (§19.2-U6) | ✅ con U6 |
| D99 | No aplica al sujeto (garante del sistema) | — | ✅ por diseño |

**Resultado de la verificación:** 14/14 planos con representación del sujeto especificada
(D3 y D99 N/A por diseño) — completitud alcanzada con las resoluciones U1 y U6 de §19.2.

### 19.2 La verificación de completitud — RESOLUCIONES U1–U7 (normas + estándares + industria)

> Verificación ejecutada y **resuelta documentalmente** en este anexo (2026-07-11). La
> materialización en DDL/código sigue el cauce de la serie de reparación (evidencia AA-1/VPS
> en su fase); la ESPECIFICACIÓN queda establecida aquí.

| # | Hallazgo | Fundamento (norma + industria) | **RESOLUCIÓN especificada** |
|---|---|---|---|
| **U1** | El contrato registraba qué TIENE el sujeto (lado AAL) pero no **a qué nivel fue verificada su identidad** (proofing) | **NIST SP 800-63A**: IAL1 auto-declarado · IAL2 (evidencia FAIR+STRONG o SUPERIOR + atributos núcleo, remoto o presencial) · IAL3 presencial. **Industria verificada:** los IdP enterprise registran el proofing del sujeto con **log a prueba de manipulación por evento de verificación (fuentes de evidencia + método + atestación)** — Entra Verified ID con verificadores certificados ISO 30107-3 + IAL2/AAL2; Okta IDV (Persona/CLEAR/Incode) para IAL2. El registro IAL1-3 ya es responsabilidad declarada del daemon (ciclo de credenciales → A.09) | **Sección `identity_proofing` en B1:** `{ial_achieved: IAL1\|IAL2\|IAL3, proofing_type: remote_unattended\|remote_attended\|in_person, evidence: [{type: FAIR\|STRONG\|SUPERIOR, kind, verified_at}], proofed_at, proofed_by, reproofing_due}` — cada evento de proofing emite su `aud_event` (el log inalterable ya existe: C3) |
| **U2** | `"CRYSTALS-Dilithium"` — nomenclatura PQC superada e incoherente con el rol | **FIPS 204 (2024): ML-DSA** (7.03 §5.3); el catálogo declarativo `crypto_algorithm` (FIPS 140-3) gobierna los algoritmos autorizados (2.01 §7) | **`algorithm: EdDSA_Ed25519` + `post_quantum_planned: ML-DSA (FIPS 204)`** — idéntico patrón que el rol (A.01 §B1); el cambio es una fila del catálogo, no código |
| **U3** | Templates biométricos con `PBKDF2-SHA256/310000` | 800-63B Rev.4 · OWASP ASVS 2.4.3 (Argon2id) — **ya declarado nativo**: `auth_config.hash.argon2id.params` por tier (2.01 §7.4) | **Argon2id es la política vigente**; los templates PBKDF2 existentes migran por **re-enrolamiento** (el hash biométrico no se convierte: se recaptura con la política nueva) |
| **U4** | `uuid` declarado "UUID v4" | RFC 9562 · decisión canónica G-B01-01 (`uuidv7()` time-ordered, no enumerable) | **Convención vigente: uuidv7 para toda identidad nueva**; los v4 existentes permanecen válidos (el uuid es inmutable — invariante 3) |
| **U5** | `phones[].purpose` incluía `"sms_otp"` | 800-63B Rev.4 §5.1.3 (deprecado); el RolTemplate ya lo marca DEPRECADO | **`sms_otp` retirado de los propósitos admisibles** para registros nuevos; el mecanismo es declarativo (`auth_method.nist_status = 'deprecated'` — 2.01 §7.3); migración a TOTP/passkey |
| **U6** | D12/D13 del sujeto ausentes: sin wallet ni certificado de firma legal | **Ley 164** (la firma jurídica con validez plena la ejerce una PERSONA física) · ADSIB-FD-POLT-015 · **eIDAS: el certificado cualificado pertenece al firmante** · EIP-155. La contraparte del rol: A.01 §17.2-B19 (operar en cadena) y §17.4-1 (política D13) | **Sección `legal_signature_identity` en el sujeto:** `{wallet_address, wallet_custody: 'vault', adsib_cert_serial, adsib_cert_expiry, adsib_cert_status, blockchain_enabled_since}` — el ROL define cuándo se exige firma legal (A.01: política D13); el SUJETO porta el certificado y la wallet. Coherencia de época: los átomos D13 ya están diseñados (5929–5964, 1.01 §4) |
| **U7** | Nombres/destinos de época (`keycloak_credentials`, `kc_*`, bindings, flujo JML del artefacto) | **ADR-010 — YA RESUELTO POR LOS MANUALES:** motor nativo 9 métodos + JWT propio + OIDC Provider nativo + framework declarativo (2.01) · JML soberano (1.08 §7) | **Este anexo refleja la materialización nativa en cada lectura de bloque** (§7, §9, §17, §18, §21); los nombres de época viven solo en el traslado histórico (§22) |

---

## 20. Validaciones, PII e invariantes

**Validaciones de esquema (del contrato):** `uuid` único · `username` único por tenant (regex
`^[a-z][a-z0-9._-]{2,64}$`) · `account_type` del catálogo · rol asignado debe existir y estar
ACTIVE · **al menos 1 factor MFA si el rol exige LoA ≥ 2** (`MFA_NOT_CONFIGURED`) ·
**certificaciones bloqueantes CURRENT para HUMAN** (`BLOCKING_CERT_MISSING`).

**Validaciones semánticas:** cobertura de credenciales (`covers_required_methods` antes de
ACTIVE) · **consentimiento biométrico obligatorio si hay templates** · SoD sobre los roles
activos · delegaciones verificadas contra el `delegation_config` del rol origen.

**PII y enmascaramiento (siempre, salvo zona RRHH + LoA 3):** birth_date, national_id,
card_number, serial_number, phone parcial; `password` y `template_hash` **JAMÁS retornados**.

**Los 6 invariantes de seguridad del contrato** (doctrina ampliada en 1.08 §10): (1) biométrico
crudo jamás — solo hash; (2) contraseña jamás en el template — vive en el almacén de
credenciales; (3) UUID inmutable; (4) permisos jamás en el usuario — siempre heredados del rol;
(5) un solo rol activo por defecto — múltiples exigen aprobación ARB; (6) consentimiento
biométrico explícito (boolean + fecha).

---

## 21. El ciclo JML del contrato

**El flujo vigente es el JML soberano de 1.08 §7** (el flujo del artefacto v6.0, con sus pasos
de época, quedó superado — se conserva solo en §22):

- **JOINER (5 pasos nativos):** alta (admin o conector RRHH vía biedata) → PENDING con
  validación de rol ACTIVE y certificaciones bloqueantes → validación del contrato (15
  secciones) → cómputo de autoridad (RolBitMask precomputado → cache) → enrolamiento de
  credenciales (contraseña Argon2id por tier + el MFA que el rol exige, nativos) → ACTIVE:
  primer login, ctx_id promovido, **JWT propio emitido**.
- **MOVER:** RRHH actualiza → validación SoD del nuevo conjunto → recálculo del RolBitMask →
  reconcile propaga → auditoría del delta (qué ganó, qué perdió).
- **LEAVER:** RRHH marca la salida (vía biedata) → **revocación de TODAS las sesiones < 30 s**
  (ctx invalidado, tokens muertos) → roles desactivados con `revoked_by` → TERMINATED →
  **retención por jurisdicción (Bolivia: 10 años, Ley 843)** y purga al plazo — coherente con
  el calendario del motor (1.13 §10.1); el uuid JAMÁS se reutiliza.

---

## 22. Traslado fiel — la estructura JSONB completa del contrato v6.0

> **Regla de autosuficiencia:** este anexo es la nueva documentación — la estructura viaja
> completa (extracción literal del original, no transcripción). §3–§18 son su lectura
> normativa; esto es el artefacto íntegro. Origen histórico (solo cita): `SBOS-USERTEMPLATE-v6_0`.

### 22.1 La estructura de los 16 bloques (íntegra)

```json
{
  "user": {

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 1 — IDENTIFICACIÓN Y METADATOS
    // Propósito: Identidad canónica inmutable del usuario en el SBOS.
    // Estándar: SCIM 2.0 RFC 7643 §4.1, ISO/IEC 24760-1 §5
    // ═══════════════════════════════════════════════════════════════════

    "id": 1001,
    // ID interno de base de datos — autoincremental, solo para joins.

    "uuid": "550e8400-e29b-41d4-a716-446655440000",
    // UUID v4 — identificador global INMUTABLE del usuario.
    // Este es el `sub` claim en el JWT de Keycloak.
    // Persiste incluso después de offboarding (para auditoría histórica).

    "external_id": "EMP789456",
    // ID en el sistema de RRHH externo (OrangeHRM, SAP, etc.).
    // Usado para sincronización SCIM 2.0 bidireccional.

    "username": "maria.garcia",
    // Nombre de usuario canónico. Formato: {nombre}.{apellido}
    // Único por tenant. INMUTABLE post-creación.

    "tenant_id": "empresa-acme",
    // Realm de Keycloak al que pertenece este usuario.
    // Capa 1 del modelo de 6 capas SAM-128.

    "empresa_id": "NIT-1234567890",
    // Empresa específica dentro del tenant (para multi-empresa).
    // Capa 2 del modelo de 6 capas SAM-128.

    "version": "1.1.0",
    // Versión semántica del contrato de este usuario.

    "status": "ACTIVE",
    // ACTIVE      → usuario operativo
    // INACTIVE    → cuenta pausada (vacaciones largas, permiso)
    // SUSPENDED   → acceso bloqueado (investigación, incidente)
    // TERMINATED  → usuario dado de baja (offboarding completado)
    // PENDING     → pendiente activación (recién creado, sin activar)

    "account_type": "HUMAN",
    // HUMAN       → persona física
    // SERVICE     → service account para integraciones (never MFA, never biométrico)
    // SYSTEM      → cuenta de sistema interno (bAuth, bkernel)
    // GUEST       → acceso temporal externo (auditor, consultor)

    "digital_signature": {
      // Firma digital del contrato de identidad del usuario.
      // Garantiza integridad del UserTemplate.
      "signature":            "base64_encoded_EdDSA_signature",
      "algorithm":            "CRYSTALS-Dilithium",
      "certificate_thumbprint":"sha256:abc123...",
      "timestamp":            "2026-01-15T08:00:00Z",
      "validity": {
        "not_before": "2026-01-15T00:00:00Z",
        "not_after":  "2027-01-15T23:59:59Z"
      }
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 2 — INFORMACIÓN PERSONAL (PII)
    // Propósito: Datos personales del usuario.
    // RGPD: estos campos son PII — logging extra, acceso restringido.
    // Estándar: SCIM 2.0 RFC 7643 §4.1.2, OpenID Connect Core claims
    // ═══════════════════════════════════════════════════════════════════

    "personal_info": {
      "_classification": "CONFIDENTIAL",
      // Clasificación de datos — controla acceso y enmascaramiento.
      // Ningún rol operativo puede ver todos estos campos sin LoA 3.

      "basic": {
        "given_name":       "María",
        // OIDC: given_name claim
        "family_name":      "García",
        // OIDC: family_name claim
        "second_family_name":"López",
        // Segundo apellido (España, LatAm)
        "full_name":        "María García López",
        // OIDC: name claim — calculado automáticamente
        "birth_date":       "1985-06-15",
        // Formato ISO 8601. Acceso restringido a RRHH.
        "gender":           "F",
        // M | F | NB | NR (no responde) — RGPD: dato sensible
        "nationality":      "BOL",
        // ISO 3166-1 alpha-3
        "national_id":      "****5678Z",
        // Siempre enmascarado en respuestas API. Solo RRHH puede ver completo.
        "national_id_type":  "DNI",
        // DNI | PASSPORT | CI (Cédula) | RUT | CURP | etc.
        "marital_status":   "MARRIED",
        // SINGLE | MARRIED | DIVORCED | WIDOWED | NR
        "locale":           "es-BO",
        // IETF BCP 47 — idioma y región del usuario
        "zoneinfo":         "America/La_Paz"
        // IANA timezone — para mostrar fechas correctamente
      },

      "contact": {
        "emails": [
          {
            "address":           "maria.garcia@empresa.com",
            "type":              "work",
            "is_primary":        true,
            "verified":          true,
            "verified_at":       "2026-01-15T08:30:00Z",
            "verification_method":"email_link"
          },
          {
            "address":           "maria.garcia.recovery@empresa.com",
            "type":              "recovery",
            "is_primary":        false,
            "verified":          true,
            "purpose":           ["account_recovery", "security_alerts"]
          }
        ],

        "phones": [
          {
            "number":            "+591 70012345",
            "type":              "mobile",
            "is_primary":        true,
            "verified":          true,
            "country_code":      "BO",
            "purpose":           ["sms_otp", "2fa", "emergency"]
          },
          {
            "number":            "+591 22345678",
            "type":              "office",
            "is_primary":        false,
            "country_code":      "BO"
          }
        ]
      },

      "addresses": [
        {
          "type":          "work",
          "street":        "Av. Camacho 1234, Piso 4",
          "city":          "La Paz",
          "state":         "La Paz",
          "country":       "BO",
          "postal_code":   "0000",
          "coordinates": {
            "latitude":  -16.5000,
            "longitude": -68.1193,
            "accuracy_m":100
          },
          "is_primary":    true,
          "verified":      true
        }
      ],

      "emergency_contacts": [
        {
          "name":         "Juan García López",
          "relationship": "spouse",
          "phone":        "+591 70098765",
          "email":        "juan.garcia@email.com",
          "notification_channels": ["phone", "whatsapp"]
        }
      ]
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 3 — INFORMACIÓN PROFESIONAL
    // Propósito: Datos laborales del usuario.
    // Sincroniza con Tryton: company.employee + party.party.
    // Estándar: SCIM 2.0 Enterprise User Extension RFC 7643 §4.3
    // ═══════════════════════════════════════════════════════════════════

    "professional_info": {
      "employee_code":    "EMP789456",
      "job_title":        "Gerente Regional de Ventas Norte",
      "job_title_en":     "Regional Sales Manager North",
      "department":       "Ventas",
      "division":         "Comercial",
      "cost_center":      "VEN-NORTE",
      "employment_type":  "FULL_TIME",
      // FULL_TIME | PART_TIME | CONTRACTOR | INTERN | GUEST
      "employment_status":"ACTIVE",
      "hire_date":        "2024-01-15",
      "termination_date": null,
      // null = empleado activo
      "manager_uuid":     "uuid-del-manager",
      "manager_username": "carlos.ruiz",
      "office_location": {
        "building":  "HQ",
        "floor":     4,
        "desk":      "4F-123",
        "zone_id":   "PHY_ZONE_VENTAS"
        // Referencia al árbol físico de bhnexus
      },
      "reporting_line":   "VEN-NORTE → COMERCIAL → GERENCIA GENERAL",
      "certifications": [
        {
          "id":          "SALES_CERT_A",
          "name":        "Certificación de Ventas Nivel A",
          "issued_by":   "Instituto Nacional de Ventas",
          "issued_at":   "2023-06-01",
          "expires_at":  "2025-06-01",
          "verified":    true
        }
      ]
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 4 — ROL ASIGNADO
    // Propósito: Vinculación del usuario con su RolTemplate.
    // El rol determina TODOS los permisos del usuario.
    // Estándar: ANSI/INCITS 359-2004 §4.2 (User-Role Assignment)
    // ═══════════════════════════════════════════════════════════════════

    "roles_assignments": {
      "active_roles": [
        {
          "role_id":      "RGV-001",
          // ID del RolTemplate en bos_rol_template.
          "assigned_at":  "2026-01-15T08:00:00Z",
          "assigned_by":  "ADMIN.SISTEMA",
          "approved_by":  "DIRECTOR_VENTAS",
          "valid_from":   "2026-01-15T00:00:00Z",
          "valid_until":  null,
          // null = vigencia del rol (hereda validity_period del RolTemplate)
          "status":       "ACTIVE",
          "assignment_reason":"Promoción a Gerente Regional Norte — Resolución DIR-2026-001",
          "context_overrides": {
            // Excepciones individuales al RolTemplate (aprobadas por compliance).
            // Solo deben usarse para casos excepcionales documentados.
            "temporal_exceptions": [
              {
                "date":          "2026-06-20",
                "allowed_until": "22:00",
                // Este usuario puede acceder hasta las 22:00 en esa fecha específica
                "approved_by":   "DIRECTOR_VENTAS",
                "reason":        "Cierre trimestral"
              }
            ],
            "network_exceptions": []
            // Redes adicionales aprobadas individualmente (vacías por defecto)
          }
        }
      ],

      "history": [
        {
          "role_id":      "VEN-VEN-NORTE-001",
          "assigned_at":  "2024-01-15T00:00:00Z",
          "removed_at":   "2026-01-14T23:59:59Z",
          "assigned_by":  "ADMIN.SISTEMA",
          "removed_by":   "ADMIN.SISTEMA",
          "reason":       "PROMOTION",
          "documentation":"Carta de Promoción EMP789456-2026"
        }
      ],

      "temporary_assignments": [
        // Delegaciones recibidas de otros usuarios.
        {
          "delegation_id":   "DEL-2026-001",
          "delegated_from":  "uuid-del-gerente-ausente",
          "from_role_id":    "DGV-001",
          "from_username":   "carlos.ruiz",
          "valid_from":      "2026-03-15T00:00:00Z",
          "valid_until":     "2026-03-30T23:59:59Z",
          "delegated_permissions": [
            // Solo permisos delegables según delegation_config del RolTemplate DGV-001
            "zone_logical/ventas:APPROVE",
            "zone_financial/ventas:APPROVE"
          ],
          "restricted_permissions": [
            // Estos NO fueron delegados aunque el origen los tenga
            "GOV_ADMIN_USERS",
            "zone_logical/reportes:CONFIGURE"
          ],
          "reason":          "Vacaciones del Director General de Ventas",
          "approved_by":     "DIRECTOR_VENTAS",
          "auto_revoke":     true,
          "status":          "SCHEDULED"
          // SCHEDULED | ACTIVE | EXPIRED | REVOKED
        }
      ]
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 5 — CREDENCIALES REGISTRADAS EN KEYCLOAK
    // Propósito: Qué métodos de autenticación TIENE configurados este usuario.
    // IMPORTANTE: Este bloque describe lo que el usuario TIENE, no lo que REQUIERE.
    //             Los requisitos están en el RolTemplate.logical_access.requiredMethods.
    // Estándar: FIDO2/WebAuthn W3C, RFC 6238 TOTP, NIST SP 800-63B §5
    // ═══════════════════════════════════════════════════════════════════

    "keycloak_credentials": {
      "_readonly": true,
      "_description": "Estado de credenciales en Keycloak. Sincronizado desde KC vía Admin API.",

      "has_password":           true,
      "password_last_changed":  "2026-01-15T09:00:00Z",
      "password_expires_at":    "2026-04-15T09:00:00Z",
      // null si no expira (manejado por política del realm)
      "password_strength_score":87,
      // Puntuación zxcvbn 0-100. Mínimo 80 (política SBOS).

      "has_totp":               true,
      "totp_devices": [
        {
          "device_name":    "Google Authenticator — iPhone 15",
          "registered_at":  "2026-01-15T09:30:00Z",
          "last_used_at":   "2026-04-15T08:00:00Z",
          "credential_id":  "kc-cred-totp-001"
        }
      ],

      "has_webauthn":           true,
      "webauthn_credentials": [
        {
          "credential_id":  "kc-cred-wn-001",
          "device_name":    "YubiKey 5 NFC",
          "type":           "security_key",
          // security_key | platform_biometric | passkey
          "aaguid":         "2fc0579f-8113-47ea-b116-bb5a8db9202a",
          // AAGUID identifica el modelo/fabricante del autenticador
          "registered_at":  "2026-01-15T10:00:00Z",
          "last_used_at":   "2026-04-15T08:00:00Z",
          "attestation_verified": true,
          "user_verification": "required"
        },
        {
          "credential_id":  "kc-cred-wn-002",
          "device_name":    "MacBook Pro — Touch ID",
          "type":           "platform_biometric",
          "aaguid":         "adce0002-35bc-c60a-648b-0b25f1f05503",
          "registered_at":  "2026-02-01T14:00:00Z",
          "last_used_at":   "2026-04-15T08:00:00Z",
          "attestation_verified": true,
          "user_verification": "required"
        }
      ],

      "has_x509_smartcard":     false,
      "has_passkey":            false,
      "has_email_otp":          false,

      "backup_codes": {
        "generated":            true,
        "generated_at":         "2026-01-15T09:00:00Z",
        "remaining_codes":      8,
        // De 10 generados, 8 aún disponibles
        "exhausted_at":         null
      },

      "credentials_compliance": {
        // bAuth verifica que las credenciales cubren los requiredMethods del RolTemplate.
        "covers_required_methods": true,
        "missing_methods":         [],
        "compliance_checked_at":   "2026-04-15T08:00:00Z",
        "compliant":               true
      },

      "kc_user_id":             "kc-user-uuid-maria-garcia",
      // UUID interno de Keycloak — diferente al uuid del UserTemplate
      "kc_realm":               "empresa-acme",
      "kc_groups":              ["/Empresa-ACME/Ventas/Norte"],
      "kc_composite_roles":     ["RGV_001"],
      "kc_realm_roles":         ["SALES_VIEW", "SALES_WRITE", "SALES_APPROVE_10K", "REPORTS_REGIONAL"]
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 6 — CREDENCIALES FÍSICAS (Dominio Físico)
    // Propósito: Credenciales para acceso a espacios físicos.
    // Referencia al árbol de ubicaciones de bhnexus.
    // Estándar: SIA OSDP v2.2.2, ISO/IEC 14443, ISO/IEC 30107-3
    // ═══════════════════════════════════════════════════════════════════

    "physical_credentials": {
      "smart_cards": [
        {
          "id":              "SC-LPZ-001",
          "type":            "NFC_MIFARE_DESFIRE",
          "card_number":     "****4567",
          // Siempre enmascarado en respuestas API
          "facility_code":   "LPZ-001",
          "status":          "ACTIVE",
          "issued_at":       "2026-01-15T08:00:00Z",
          "expires_at":      "2027-01-15T00:00:00Z",
          "last_used_at":    "2026-04-15T08:10:00Z",
          "last_used_zone":  "PHY_ZONE_VENTAS",
          "encryption_key_version": 3
          // Referencia a versión de clave AES en Vault
        }
      ],

      "mobile_credentials": [
        {
          "id":              "MC-LPZ-001",
          "type":            "BLE_TOKEN",
          "device_id":       "iPhone15Pro-ABCD1234",
          "device_model":    "iPhone 15 Pro",
          "status":          "ACTIVE",
          "enrolled_at":     "2026-01-20T10:00:00Z"
        }
      ],

      "biometric_templates": [
        // IMPORTANTE: Solo hashes — NUNCA raw biometric data.
        // El template se captura en el lector y el hash se almacena aquí.
        // RGPD: dato biométrico especial — consentimiento explícito requerido.
        {
          "id":                  "BIO-001",
          "biometric_type":      "fingerprint",
          "finger":              1,
          // 1=pulgar derecho, 2=índice derecho, ... 6=pulgar izquierdo, etc.
          "template_hash":       "pbkdf2$sha256$310000$salt$hash_base64",
          // Formato: algorithm$hash$iterations$salt$hash
          "hash_algorithm":      "PBKDF2-SHA256",
          "iterations":          310000,
          "enrollment_policy":   "hybrid",
          // admin_only | self_service | hybrid
          "liveness_verified":   true,
          "admin_verified":      true,
          "admin_uuid":          "uuid-del-admin-que-verifico",
          "fmr_achieved":        "1:15000",
          // False Match Rate logrado durante enrollment
          "enrolled_at":         "2026-01-15T11:00:00Z",
          "enrolled_by":         "ADMIN.SEGURIDAD",
          "device_id":           "PHY_DEV_FP_SALA_VENTAS",
          // Lector donde se realizó el enrollment
          "consent_given":       true,
          "consent_date":        "2026-01-15T10:45:00Z",
          "revoked_at":          null
        },
        {
          "id":                  "BIO-002",
          "biometric_type":      "fingerprint",
          "finger":              6,
          // Pulgar izquierdo — respaldo
          "template_hash":       "pbkdf2$sha256$310000$salt2$hash2_base64",
          "hash_algorithm":      "PBKDF2-SHA256",
          "iterations":          310000,
          "enrollment_policy":   "hybrid",
          "liveness_verified":   true,
          "admin_verified":      true,
          "enrolled_at":         "2026-01-15T11:15:00Z",
          "enrolled_by":         "ADMIN.SEGURIDAD",
          "consent_given":       true,
          "consent_date":        "2026-01-15T11:00:00Z",
          "revoked_at":          null
        }
      ],

      "qr_config": {
        // Configuración para generación de QR dinámico.
        "enabled":         true,
        "ttl_seconds":     30,
        // QR válido por 30 segundos desde generación
        "last_generated":  "2026-04-15T08:05:00Z",
        "hmac_key_version":5
        // Versión de la clave HMAC en Vault (rotada cada 90 días)
      }
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 7 — BINDING CON SISTEMAS EXTERNOS
    // Propósito: Vinculación del usuario con sistemas del ecosistema SBOS.
    // Estándar: SCIM 2.0 RFC 7643/7644
    // ═══════════════════════════════════════════════════════════════════

    "system_bindings": {
      "tryton": {
        "user_id":       1547,
        "employee_id":   2341,
        "party_id":      3421,
        "company_id":    1,
        "language":      "es",
        "active":        true,
        "groups":        ["RGV_001"],
        "last_synced_at":"2026-04-15T08:00:00Z"
      },

      "orangehrm": {
        "employee_id":   "EMP789456",
        "user_id":       "ohrm-user-456",
        "active":        true,
        "last_synced_at":"2026-04-15T06:00:00Z"
      },

      "espocrm": {
        "user_id":       "espo-uuid-maria",
        "active":        true,
        "teams":         ["VENTAS_NORTE"]
      },

      "superset": {
        "user_id":       "sup-user-maria",
        "roles":         ["SALES_REGIONAL"],
        "active":        true
      }
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 8 — PREFERENCIAS DE UI Y PERSONALIZACIÓN
    // Propósito: Configuración de la interfaz de usuario.
    // No tiene impacto en seguridad — solo UX.
    // ═══════════════════════════════════════════════════════════════════

    "ui_preferences": {
      "theme": {
        "mode":          "light",
        // light | dark | auto (sigue preferencia del SO)
        "color_scheme":  "blue",
        "font_size":     "medium",
        // small | medium | large | extra_large (accesibilidad)
        "accessibility": {
          "high_contrast":  false,
          "reduce_motion":  false,
          "screen_reader":  false
        }
      },
      "layout": {
        "sidebar_collapsed":  false,
        "dashboard_widgets":  ["tasks", "calendar", "notifications", "sales_kpi"],
        "default_views": {
          "calendar":  "week",
          "reports":   "summary",
          "sales":     "pipeline"
        },
        "start_page":    "dashboard_ventas"
      },
      "notifications": {
        "email":          true,
        "push":           true,
        "desktop":        true,
        "sms":            false,
        "quiet_hours": {
          "enabled": true,
          "start":   "19:00",
          "end":     "08:00",
          "timezone":"America/La_Paz"
        }
      },
      "language": {
        "preferred": "es",
        "fallback":  "en",
        "date_format":   "DD/MM/YYYY",
        "time_format":   "24h",
        "number_format": "1.234,56"
        // Formato boliviano: punto para miles, coma para decimales
      }
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 9 — CUMPLIMIENTO TERRITORIAL Y NORMATIVO
    // Propósito: Restricciones legales del país de operación del usuario.
    // Estándar: RGPD Art.46, eIDAS, ISO/IEC 27701
    // ═══════════════════════════════════════════════════════════════════

    "territorial_compliance": {
      "primary_jurisdiction": "BO",
      // ISO 3166-1 alpha-2 — Bolivia

      "applicable_regulations": [
        "LEY_BOL_PROTECCION_DATOS",
        "LEY_843_TRIBUTARIA",
        "NORME_SIAT"
        // Regulaciones locales bolivianas — bAuth activa GOV_NORMATIVE_BO en SAM-128
      ],

      "data_residency": {
        "personal_data":    "BO",
        // Datos personales deben residir en Bolivia (regulación local)
        "financial_data":   "BO",
        "backup_location":  "LATAM"
        // Backup puede estar en región LATAM
      },

      "geo_restrictions": {
        "allowed_access_countries": ["BO", "AR", "BR", "CL", "PE"],
        // Países desde donde puede acceder
        "blocked_regions":          [],
        "require_vpn_from_abroad":  true
        // Requiere VPN si accede desde fuera de países permitidos
      },

      "privacy": {
        "consent_given":         true,
        "consent_date":          "2026-01-15T08:00:00Z",
        "consent_version":       "PRIVACY_POLICY_v2.1",
        "data_processing_basis": "CONTRACT",
        // CONSENT | CONTRACT | LEGAL_OBLIGATION | VITAL_INTERESTS | PUBLIC_TASK | LEGITIMATE_INTEREST
        "data_subject_rights": {
          "access_requested":    false,
          "portability_given":   false,
          "erasure_requested":   false,
          "restriction_active":  false
        }
      }
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 10 — GESTIÓN DE PERSISTENCIA Y SESIONES
    // Propósito: Configuración técnica del ciclo de vida de sesiones.
    // Estándar: NIST SP 800-63B §7 (Session Management), OWASP Session Mgmt
    // ═══════════════════════════════════════════════════════════════════

    "persistence_management": {
      "session_tracking": {
        "current_session": {
          "id":                   "sess_2026041512345",
          "created_at":           "2026-04-15T08:00:00Z",
          "last_activity":        "2026-04-15T10:30:00Z",
          "expires_at":           "2026-04-15T16:00:00Z",
          "device_id":            "LAP-2026-001",
          "ip_address":           "10.0.1.45",
          "node_id":              "Ventas-01",
          "authentication_level": "FULL",
          "mfa_status":           "VERIFIED",
          "mfa_method":           "totp",
          "loa_achieved":         2,
          "acr_value":            "standard"
        },
        "history": {
          "last_successful_login":   "2026-04-15T08:00:00Z",
          "last_failed_login":       null,
          "failed_attempts_today":   0,
          "total_sessions_30d":      22
        }
      },

      "token_management": {
        "access_token": {
          "type":              "JWT",
          "ttl_minutes":       60,
          "refresh_window_m":  50
          // Empieza a renovar cuando quedan 10 min de vida
        },
        "refresh_token": {
          "type":              "opaque",
          "ttl_days":          7,
          "single_use":        true,
          "rotation_policy":   "single_use"
        }
      },

      "device_trust": {
        "trusted_devices": [
          {
            "device_id":       "LAP-2026-001",
            "trust_score":     95,
            "trust_level":     "HIGH",
            "last_verified":   "2026-04-15T08:00:00Z",
            "compliance_status":"COMPLIANT"
          }
        ]
      }
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 11 — GESTIÓN DE DISPOSITIVOS
    // Propósito: Dispositivos corporativos y personales del usuario.
    // Estándar: NIST SP 800-124 (Mobile Device Security), MDM policies
    // ═══════════════════════════════════════════════════════════════════

    "device_management": {
      "registered_devices": [
        {
          "id":             "LAP-2026-001",
          "type":           "laptop",
          "manufacturer":   "Dell",
          "model":          "Latitude 7430",
          "os":             "Fedora KDE 41",
          "hostname":       "WS-MGARCIA-01",
          "serial_number":  "****XYZ",
          "asset_tag":      "ACME-IT-2026-001",
          "ownership":      "CORPORATE",
          // CORPORATE | BYOD
          "mdm_enrolled":   true,
          "banexus_installed": true,
          // banexus.service corriendo en este dispositivo
          "last_seen":      "2026-04-15T10:30:00Z",
          "security_status": {
            "encryption":          true,
            "antivirus":           "ClamAV — up-to-date",
            "firewall":            "enabled",
            "patch_level":         "current",
            "tpm_version":         "2.0",
            "secure_boot":         true,
            "banexus_integrity_ok":true
          },
          "compliance_level":"FULL",
          "trust_score":    95,
          "certificate_thumbprint": "sha256:device-cert-abc123"
        },
        {
          "id":             "MOB-2026-001",
          "type":           "smartphone",
          "manufacturer":   "Apple",
          "model":          "iPhone 15 Pro",
          "os":             "iOS 18.3",
          "serial_number":  "****9012",
          "ownership":      "CORPORATE",
          "mdm_enrolled":   true,
          "banexus_installed": false,
          // banexus no se instala en móviles — solo app SBOS
          "sbos_app_installed": true,
          "last_seen":      "2026-04-15T10:15:00Z",
          "security_status": {
            "encryption":     true,
            "screen_lock":    "enabled",
            "biometric_lock": true,
            "jailbreak_status":"clean",
            "app_version":    "2.1.0"
          },
          "compliance_level":"FULL"
        }
      ],

      "trusted_networks": [
        {
          "name":              "La Paz HQ",
          "ip_ranges":         ["10.0.1.0/24", "192.168.10.0/24"],
          "security_level":    "HIGH",
          "requires_certificate": true,
          "zone_id":           "PHY_SITE_LPZ_001"
        },
        {
          "name":              "VPN Corporativa",
          "ip_ranges":         ["10.10.0.0/16"],
          "security_level":    "HIGH",
          "vpn_type":          "IPSec",
          "requires_certificate": true
        }
      ],

      "vpn_configurations": [
        {
          "profile_name":    "VPN Corporativa SBOS",
          "type":            "IKEv2",
          "protocol":        "IPSec",
          "server":          "vpn.empresa-acme.com",
          "authentication":  ["certificate", "totp"],
          "encryption":      "AES-256-GCM",
          "auto_connect":    false,
          "split_tunnel":    false
          // false = todo el tráfico por VPN (más seguro)
        }
      ]
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 12 — CUMPLIMIENTO Y CAPACITACIÓN
    // Propósito: Rastrear certificaciones, trainings y reconocimientos de política.
    // Estándar: ISO/IEC 27001 A.6.3, PCI-DSS Req.12.6
    // ═══════════════════════════════════════════════════════════════════

    "compliance_control": {
      "certifications_status": [
        {
          "cert_id":        "ISO27001_USER_AWARENESS",
          "name":           "Concienciación ISO 27001",
          "status":         "CURRENT",
          // CURRENT | EXPIRED | PENDING | NOT_REQUIRED
          "obtained_at":    "2026-01-15T00:00:00Z",
          "expires_at":     "2027-01-15T00:00:00Z",
          "required":       true,
          "blocking":       true
          // blocking = true → sin este cert el usuario no puede ser ACTIVE
        },
        {
          "cert_id":        "PCI_DSS_CARDHOLDER",
          "name":           "PCI-DSS Manejo de Datos de Tarjeta",
          "status":         "CURRENT",
          "obtained_at":    "2026-01-15T00:00:00Z",
          "expires_at":     "2027-01-15T00:00:00Z",
          "required":       true,
          "blocking":       true
        }
      ],

      "training_status": {
        "completed_courses": [
          {
            "id":           "SEC-AWARENESS-2026",
            "name":         "Concientización de Seguridad 2026",
            "completed_at": "2026-01-10T00:00:00Z",
            "score":        92,
            "valid_until":  "2027-01-10T00:00:00Z"
          }
        ],
        "pending_courses": [
          {
            "id":       "GDPR-REFRESHER-2026",
            "name":     "Actualización RGPD 2026",
            "due_date": "2026-06-30T00:00:00Z",
            "mandatory":true
          }
        ]
      },

      "policy_acknowledgments": [
        {
          "policy_id":         "SEC-POL-2026-v2",
          "name":              "Política de Seguridad de Información 2026",
          "version":           "2.0",
          "acknowledged_at":   "2026-01-15T08:00:00Z",
          "acknowledgment_method":"electronic_signature"
        },
        {
          "policy_id":         "ACCEPTABLE-USE-2026",
          "name":              "Política de Uso Aceptable de TI",
          "version":           "1.5",
          "acknowledged_at":   "2026-01-15T08:00:00Z",
          "acknowledgment_method":"electronic_signature"
        }
      ]
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 13 — PERFILES DE SEGURIDAD Y ANÁLISIS DE COMPORTAMIENTO
    // Propósito: Score de riesgo dinámico del usuario.
    // bAuth + bkernel actualizan estos datos en tiempo real.
    // Estándar: NIST SP 800-63B §9 (Reauthentication), UEBA patterns
    // ═══════════════════════════════════════════════════════════════════

    "security_profiles": {
      "risk_score": {
        "overall":           0.15,
        // 0.0 = sin riesgo, 1.0 = máximo riesgo. Calculado continuamente.
        "component_scores": {
          "authentication":  0.10,
          // Historial de fallos de autenticación
          "device_security": 0.05,
          // Postura de seguridad de dispositivos
          "behavior_pattern":0.20,
          // Desviación de patrones normales
          "location_risk":   0.10,
          // Accesos desde ubicaciones inusuales
          "compliance":      0.20
          // Estado de cumplimiento de certificaciones
        },
        "risk_level":        "LOW",
        // LOW | MEDIUM | HIGH | CRITICAL
        "computed_at":       "2026-04-15T10:30:00Z",
        "trending":          "STABLE"
        // IMPROVING | STABLE | DETERIORATING
      },

      "behavior_analytics": {
        "baseline_established": true,
        "baseline_period_days": 30,
        "login_patterns": [
          {
            "pattern":        "weekday_morning",
            "frequency":      "92%",
            "typical_hours":  "07:45-08:15",
            "device":         "LAP-2026-001",
            "location":       "La Paz HQ"
          }
        ],
        "access_anomalies": [],
        // Lista vacía = sin anomalías recientes
        "keyboard_dynamics": {
          "baseline_established": true,
          "last_updated":         "2026-04-14T08:00:00Z",
          "confidence":           0.94,
          "_note": "Template hash almacenado en bauth_db, nunca aquí"
        }
      },

      "security_incidents": [],
      // Historial de incidentes de seguridad del usuario.
      // Vacío = sin incidentes.

      "mfa_compliance": {
        "compliant":             true,
        "last_mfa_success":      "2026-04-15T08:00:00Z",
        "consecutive_failures":  0,
        "lockout_active":        false,
        "lockout_until":         null
      }
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 14 — ACCESO CONTEXTUAL (Sobrescrituras aprobadas individualmente)
    // Propósito: Excepciones individuales al RolTemplate base — raramente usadas.
    // IMPORTANTE: Toda excepción requiere aprobación documentada.
    // ═══════════════════════════════════════════════════════════════════

    "contextual_access": {
      "_note": "Sobrescrituras individuales al RolTemplate. Todas requieren aprobación + documentación.",

      "location_exceptions": [
        // Redes adicionales aprobadas solo para este usuario.
        // El RolTemplate define la lista base — esto es adicional.
        {
          "name":              "Oficina Satélite Cochabamba",
          "network_ranges":    ["192.168.20.0/24"],
          "approved_by":       "DIRECTOR_VENTAS",
          "approved_at":       "2026-03-01T00:00:00Z",
          "valid_until":       "2026-06-30T00:00:00Z",
          "reason":            "Proyecto Expansión Norte — visitas mensuales"
        }
      ],

      "temporal_exceptions": [],
      // Fechas/horarios adicionales aprobados individualmente.

      "device_exceptions": []
      // Dispositivos adicionales no en la lista estándar.
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 15 — INTEGRACIONES CON SISTEMAS EXTERNOS
    // Propósito: Estado de integración con RRHH, SSO, MFA providers.
    // ═══════════════════════════════════════════════════════════════════

    "system_integrations": {
      "hr_system": {
        "provider":        "OrangeHRM",
        "employee_id":     "EMP789456",
        "sync_status":     "SYNCED",
        "last_sync":       "2026-04-15T06:00:00Z",
        "sync_fields":     ["job_title", "department", "manager", "employment_status"]
      },

      "sso_providers": [
        {
          "provider":      "SBOS Keycloak",
          "realm":         "empresa-acme",
          "status":        "ACTIVE",
          "last_login":    "2026-04-15T08:00:00Z",
          "protocol":      "OIDC"
        }
      ],

      "mfa_services": [
        {
          "provider":      "Google Authenticator",
          "type":          "TOTP",
          "status":        "ENROLLED",
          "enrolled_at":   "2026-01-15T09:30:00Z",
          "last_used":     "2026-04-15T08:00:00Z"
        }
      ],

      "directory_services": [
        {
          "type":          "LDAP",
          "server":        "ldap.empresa-acme.internal",
          "dn":            "cn=maria.garcia,ou=ventas,dc=empresa-acme,dc=com",
          "synced":        true,
          "last_sync":     "2026-04-15T06:00:00Z"
        }
      ]
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 16 — AUDITORÍA Y ESTADO DE SINCRONIZACIÓN
    // Propósito: Trazabilidad completa y estado de sincronización.
    // Solo lectura — gestionado por bAuth.
    // ═══════════════════════════════════════════════════════════════════

    "audit": {
      "created_by":       "ADMIN.SISTEMA",
      "created_at":       "2026-01-15T08:00:00Z",
      "updated_by":       "ADMIN.SISTEMA",
      "updated_at":       "2026-04-15T08:00:00Z",
      "onboarding_completed_at": "2026-01-15T10:00:00Z",
      "offboarding_started_at":  null,
      "offboarding_completed_at":null
    },

    "sync_state": {
      "_readonly":     true,
      "_description":  "Gestionado exclusivamente por bAuth. No editar.",
      "sync_status":   "SYNCED",
      // PENDING | SYNCING | SYNCED | ERROR | DRIFT
      "last_sync_at":  "2026-04-15T08:00:00Z",
      "sync_targets": {
        "keycloak": {
          "status":        "SYNCED",
          "kc_user_id":    "kc-user-uuid-maria-garcia",
          "last_synced_at":"2026-04-15T08:00:00Z"
        },
        "tryton": {
          "status":        "SYNCED",
          "tryton_user_id":1547,
          "last_synced_at":"2026-04-15T08:00:00Z"
        },
        "orangehrm": {
          "status":        "SYNCED",
          "last_synced_at":"2026-04-15T06:00:00Z"
        }
      }
    }

  }
}
```

### 22.2 Flujo JML, validaciones, PII e invariantes (texto íntegro del contrato)

#### FLUJO DE ONBOARDING (Ciclo de Vida del UserTemplate)

```
PASO 1: Admin crea UserTemplate en Core UI
  → Estado: PENDING
  → bAuth valida: RolTemplate existe y está ACTIVE
  → bAuth valida: certifications_status no bloqueantes

PASO 2: bAuth sincroniza a Keycloak
  → Crea user record con atributos del RolTemplate asignado
  → Configura Authentication Flow del RolTemplate
  → Asigna grupos KC y Composite Roles
  → KC envía email de activación al usuario

PASO 3: bAuth sincroniza a Tryton
  → Crea/actualiza res.user con login = username
  → Asigna grupo = {role_id}
  → Las 5 capas de enforcement activan automáticamente

PASO 4: Usuario activa su cuenta
  → Configura contraseña (política del realm KC)
  → Configura TOTP o WebAuthn (requerido por RolTemplate)
  → Estado: ACTIVE

PASO 5: Operación normal
  → Usuario se autentica → KC evalúa Authentication Flow
  → JWT emitido con claims bos_*
  → bAuth evalúa SAM-128 en tiempo real
  → Tryton enforcea 5 capas en cada operación

OFFBOARDING (cuando empleado sale):
  PASO 1: HR actualiza OrangeHRM → sync bAuth
  PASO 2: bAuth revoca todas las sesiones activas (< 30 segundos)
  PASO 3: bAuth desactiva en KC (realm_access roles revocados)
  PASO 4: bAuth marca en Tryton (active = false)
  PASO 5: Estado: TERMINATED
  PASO 6: Retención de datos según RGPD + jurisdicción
          Bolivia: 10 años (Ley 843)
```

---

#### REGLAS DE VALIDACIÓN

##### Validaciones de Schema

| Campo | Regla | Error |
|---|---|---|
| `uuid` | UUID v4 válido y único | `DUPLICATE_UUID` |
| `username` | Único por tenant, regex `^[a-z][a-z0-9._-]{2,64}$` | `INVALID_USERNAME` |
| `account_type` | HUMAN\|SERVICE\|SYSTEM\|GUEST | `INVALID_ACCOUNT_TYPE` |
| `roles_assignments.active_roles[].role_id` | Debe existir en `bos_rol_template` con status ACTIVE | `ROLE_NOT_FOUND` |
| `keycloak_credentials.has_totp OR has_webauthn` | Al menos 1 factor MFA cuando role requiere LoA >= 2 | `MFA_NOT_CONFIGURED` |
| `compliance_control.certifications_status[blocking=true]` | Todos con status=CURRENT para account_type=HUMAN | `BLOCKING_CERT_MISSING` |

##### Validaciones Semánticas

| Regla | Descripción |
|---|---|
| **Credential coverage** | `credentials_compliance.covers_required_methods = true` antes de ACTIVE |
| **Biometric consent** | Si hay biometric_templates → consent_given debe ser true |
| **SoD check** | Roles en active_roles no deben violar SoD del tenant |
| **Delegation valid** | temporary_assignments verificados contra delegation_config del RolTemplate fuente |

---

#### CAMPOS PII Y ENMASCARAMIENTO

Los siguientes campos son PII bajo RGPD — siempre enmascarados en respuestas API salvo roles con `zone_logical/rrhh:READ` + LoA 3:

```
personal_info.basic.birth_date      → "****-**-**"
personal_info.basic.national_id     → "****5678Z"
physical_credentials.*.card_number  → "****4567"
physical_credentials.*.serial_number→ "****XYZ"
personal_info.contact.phones.number → "+591 7****5"
keycloak_credentials.password       → [NEVER RETURNED]
physical_credentials.biometric_templates.template_hash → [NEVER RETURNED via API]
```

---

#### INVARIANTES DE SEGURIDAD

1. **Raw biometric NUNCA en el UserTemplate** — solo hashes PBKDF2-SHA256
2. **Contraseña NUNCA en el UserTemplate** — vive solo en Keycloak (bcrypt)
3. **UUID INMUTABLE** — nunca cambia aunque el usuario cambie de rol o empresa
4. **Permisos NUNCA en el UserTemplate** — siempre heredados del RolTemplate
5. **Un solo rol activo por defecto** — múltiples roles requieren aprobación ARB
6. **Consentimiento biométrico EXPLÍCITO** — campo boolean + fecha

---

---

## 22.bis Estado de materialización en código (verificado 2026-07-11)

| Pieza | Evidencia | Estado |
|---|---|---|
| Tabla `idn_user_template` | `sbos_00__esquema_base.sql` (`CREATE TABLE`) | ✅ existe |
| Asignación `idn_user_role` | `sbos_00` | ✅ |
| Validador de las 15 secciones | `usertemplate_validator.rs` (**495 líneas** — el más extenso, A.23) | ✅ real |
| Los campos 1:N (emails/phones) → `idn_atributo` | **`idn_atributo` NO existe en DDL** (A.31 — 0 menciones) | ❌ **la tabla destino falta** |

**Hallazgo crudo:** el UserTemplate tiene tabla y validador reales (495 líneas), **pero la
tabla `idn_atributo`** donde deben materializarse sus campos multivaluados (B2/B3, regla 1.08 §3)
**no existe en el esquema** (A.31-AT1, P1). Hoy esos 1:N o van al JSONB (contra la regla) o no se
guardan. Las resoluciones U1–U7 (§19.2) son especificación, pendientes de materializar.

## 23. Mapa anexo → manuales

| Sección de este anexo | Respalda a |
|---|---|
| §B1 (identidad canónica, firma) | 1.08 §3-§4 · 1.12 (tenant) · 2.04 (firma) |
| §B2-§B3 (PII, profesional) | 1.08 §9 · 2.10 (clasificación/PII) · 1.07 (atributos) |
| §B4 (UA, delegaciones recibidas) | 1.08 §5 · 1.09 §9 · A.01 §B10 |
| §B5-§B6 (credenciales TIENE) | 2.01 · 2.02 (métodos) · A.01 §B4 (REQUIERE) |
| §B9 (territorial, privacidad) | 2.10 §8-§9 · 7.03 §7 (normativa boliviana) |
| §B10 (sesiones/tokens) | 2.03 Tokens · 2.01 |
| §B11 (dispositivos/postura) | 2.09 · A.01 §17.2-B16 (política D7 del rol) |
| §B12 (capacitación) | 7.01 IGA |
| §B13 (riesgo/UEBA) | 3.01 Riesgo Adaptativo · A.01 §17.2-B17 |
| §19 (completitud, defases U1-U7) | 1.08 · 1.01 (dominios) · el doc de gaps (tracking) |
| §20-§21 (validaciones, JML) | 1.08 §7-§10 |
| §22 (traslado fiel) | Fuente autosuficiente del contrato |

---

## 24. Referencias e historial

**Del proyecto:** `SBOS-USERTEMPLATE-v6_0` (origen histórico) · MANUAL-USER-TEMPLATE (1.08 — la
doctrina) · MANUAL-DOMINIOS (1.01 §4) · A.01 (la contraparte de autoridad) ·
`SBOS-BAUTH-USER-REGISTRATION-CREDENTIAL-LIFECYCLE` (IAL — fuente del futuro A.09) · ADR-010.

**Fuentes primarias (verificación 2026-07-11):** [RFC 7643 — SCIM Core Schema](https://datatracker.ietf.org/doc/html/rfc7643) (§4.1 Core · §4.3 Enterprise) · [NIST SP 800-63A (IAL)](https://pages.nist.gov/800-63-4/sp800-63a.html) · [NIST SP 800-63B](https://pages.nist.gov/800-63-4/sp800-63b.html) (§5 authenticators · §7 sesiones) · [Session Management — NIST](https://pages.nist.gov/800-63-3-Implementation-Resources/63B/Session/) · [INCITS 359 RBAC](https://csrc.nist.gov/projects/role-based-access-control) (`USERS`/`UA`) · [OIDC Core claims](https://openid.net/specs/openid-connect-core-1_0.html) · [FIPS 204 — ML-DSA](https://csrc.nist.gov/pubs/fips/204/final) · [ISO/IEC 30107-3](https://www.iso.org/standard/79520.html) · [RGPD](https://eur-lex.europa.eu/eli/reg/2016/679/oj)

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.1.0 | 2026-07-11 | **Añadida verificación de código real** (§22.bis: tabla+validador (495 líneas) reales, PERO idn_atributo destino de los 1:N NO existe en DDL). |
| 1.0.0 | 2026-07-11 | Anexo inicial con el patrón completo desde el origen (los 8 elementos + autosuficiencia + frontera). Estructura: los 16 bloques del contrato en lectura normativa a nivel de campo (§3–§18), la verificación de completitud contra normas y estándares (§19): matriz de los 14 planos D00–D13 proyectados sobre el SUJETO (el rol define la política; el usuario porta credenciales/señales/excepciones/consentimientos — D3 N/A por diseño, invariante 4) con 7 hallazgos U1–U7; validaciones+PII+invariantes (§20), el ciclo JML (§21), el **traslado fiel** de la estructura JSONB íntegra + reglas del contrato (§22, extracción literal) y el mapa a manuales. |
| 1.1.0 | 2026-07-11 | **Verificación de completitud RESUELTA + materialización nativa reflejada** (corrección del humano: bAuth es autosuficiente — los manuales ya documentan la solución; y la completitud se resuelve con normas+estándares+industria, sin esperar decisión). §19.2 pasa de "defases para HITL" a **RESOLUCIONES**: U1 especificada la sección `identity_proofing` (800-63A: IAL, tipo de proofing, evidencia FAIR/STRONG/SUPERIOR, evento auditado — verificado contra la industria: Entra Verified ID con verificadores ISO 30107-3+IAL2/AAL2, Okta IDV con Persona/CLEAR/Incode, log inalterable por evento); U2 EdDSA+ML-DSA (FIPS 204, catálogo `crypto_algorithm`); U3 Argon2id por re-enrolamiento (`auth_config` ya lo declara por tier — 2.01 §7.4); U4 convención uuidv7; U5 sms_otp retirado (`auth_method.nist_status` declarativo); U6 especificada `legal_signature_identity` del sujeto (wallet custodia vault + certificado ADSIB — Ley 164/eIDAS: el certificado es de la persona; el rol define cuándo se exige — A.01 D13); U7 resuelto por los manuales. **Las lecturas §1/§7/§9/§17/§18/§21 describen la materialización NATIVA vigente** (framework declarativo de 7 tablas, `ath_*`, OIDC Provider nativo, biedata como aduana, JML soberano 1.08 §7) — los nombres de época quedan solo en el traslado histórico §22. Matriz §19.1: 14/14 planos con representación del sujeto especificada. |
