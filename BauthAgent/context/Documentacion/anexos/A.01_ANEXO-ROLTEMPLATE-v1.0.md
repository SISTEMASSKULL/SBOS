# Anexo A.01 — El Contrato RolTemplate v6.0
## Documento de respaldo: estructura completa, origen normativo campo a campo y estado de materialización

**Tipo:** ANEXO — documento de respaldo del corpus (no es un manual; los manuales afirman, este anexo respalda)
**Versión del anexo:** 2.2.0 · **Fecha:** 2026-07-14
**Estatus:** FUENTE AUTOSUFICIENTE — contiene la estructura COMPLETA del contrato (traslado fiel, §19); la documentación de origen queda como cita histórica y **no es fuente de lectura**
**Respalda a:** MANUAL-ROLES (1.09) §2.5/§7/§11 · MANUAL-D00-IDENTIDAD v2.0 (1.06) · MANUAL-ATRIBUTOS v2.0 (1.07) · MANUAL-MOTOR-IDENTIDAD (2.15) · MANUAL-MOTOR-VERSIONADO (1.13) §9.2 · MANUAL-BITMASK (1.04) · MANUAL-POLITICAS (2.05)
**Fuentes de origen:** `SBOS-ROLTEMPLATE-v6_0` (contrato definitivo, jun-2026) · `BAUTH-ORIGEN-NORMATIVO-ROLTEMPLATE-2026-07-08` (mapa campo→norma, códigos G-B*) · resoluciones G-B01-01…05 / G-B02-01…02 (estado real en VPS)
**Normas base:** ANSI INCITS 359 (RBAC: Core·Hierarchical·SSD·DSD) · NIST SP 800-63B · NIST SP 800-53 (AC-2/3/5/6, CM-3, AU-*) · ISO 27001:2022 · ISO 24760 · OASIS XACML 3.0 / NIST SP 800-162 · RFC 9470 · PCI DSS 4.0 · SOX · SIN RND · Ley 164

---

## Tabla de contenidos

1. [Propósito del anexo y cómo citarlo](#1-propósito-del-anexo-y-cómo-citarlo)
2. [El contrato en una vista](#2-el-contrato-en-una-vista)
3. [B1 — Identificación y metadatos](#3-b1--identificación-y-metadatos)
4. [B2 — Vigencia y ciclo de vida](#4-b2--vigencia-y-ciclo-de-vida)
5. [B3 — Flujo de aprobación](#5-b3--flujo-de-aprobación)
6. [B4 — Dominio lógico (autenticación digital)](#6-b4--dominio-lógico-autenticación-digital)
7. [B5 — Dominio físico (acceso presencial)](#7-b5--dominio-físico-acceso-presencial)
8. [B6 — Zonas de negocio](#8-b6--zonas-de-negocio)
9. [B7 — Privilegios ERP en 5 capas](#9-b7--privilegios-erp-en-5-capas)
10. [B8 — Dominio financiero](#10-b8--dominio-financiero)
11. [B9 — SAM-128 + BitMask (calculado)](#11-b9--sam-128--bitmask-calculado)
12. [B10 — Delegación (DSD)](#12-b10--delegación-dsd)
13. [B11 — Grupos y jerarquías (RBAC1)](#13-b11--grupos-y-jerarquías-rbac1)
14. [B12 — Gestión de conflictos (SSD/SoD)](#14-b12--gestión-de-conflictos-ssdsod)
15. [B13 — Cumplimiento y auditoría](#15-b13--cumplimiento-y-auditoría)
16. [B14 — Estado de sincronización (calculado)](#16-b14--estado-de-sincronización-calculado)
17. [La estructura COMPLETA por dominios — cobertura D00–D13](#17-la-estructura-completa-por-dominios--cobertura-d00d13-y-los-bloques-por-incorporar)
18. [Las validaciones del contrato](#18-las-validaciones-del-contrato)
19. [Traslado fiel — la estructura JSONB completa](#19-traslado-fiel--la-estructura-jsonb-completa-del-contrato-v60)
20. [Mapa anexo → manuales](#20-mapa-anexo--manuales)
21. [Referencias e historial](#21-referencias-e-historial)

---

## 1. Propósito del anexo y cómo citarlo

Este anexo es el **respaldo documental estructurado** del contrato RolTemplate: consolida en
secciones numeradas y referenciables (a) la estructura completa de los 14 bloques del contrato
v6.0, (b) el origen normativo de cada parte (verificado contra fuentes primarias), y (c) el
**estado real de materialización** en la base de datos tras las resoluciones de la serie G-B*.

**Cómo citarlo:** `A.01 §B8` (un bloque) · `A.01 §B8 · límites` (una parte) · `A.01 §18` (las
validaciones). Los manuales citan el anexo; el anexo cita el contrato SSOT y las normas.

**Estatus de fuente (decisión del humano, 2026-07-11):** este anexo ES la nueva documentación
del contrato RolTemplate — contiene su estructura COMPLETA trasladada fielmente (§19) más su
lectura normativa (§3–§16) y la cobertura por dominios (§17). **La documentación de origen ya
no se consulta**: queda citada solo como origen histórico. Excepción operativa: el mapa de
gaps (`BAUTH-ORIGEN-NORMATIVO`) sigue siendo el documento de TRACKING activo de la reparación
(los códigos G-B* se resuelven allí); este anexo refleja su estado, no lo sustituye como
registro.

**Nota de época (ADR-010):** el contrato v6.0 (jun-2026) es anterior a la eliminación de los
motores externos. Sus menciones de materialización en Keycloak/Tryton (B4-sync, B7, B14) se
documentan aquí como **materialización original**, con la marca `[pre-ADR-010]` — bAuth cubre
hoy esos flujos nativamente. El contenido conceptual de esos bloques (QUÉ controlan) permanece
plenamente vigente; su CÓMO se re-especifica en la revisión del contrato (HITL pendiente).

---

## 2. El contrato en una vista

**Principio absoluto (del SSOT):** el RolTemplate es el ÚNICO contrato que define lo que un
tipo de rol PUEDE HACER en el SBOS. No hay otra forma de configurar la autoridad.

| Propiedad | Valor |
|---|---|
| Pregunta que responde | ¿Qué PUEDE HACER un tipo de rol? |
| Granularidad | Categoría organizacional (no un usuario individual) |
| Multiplicidad | Un RolTemplate → muchos usuarios |
| Contraparte | El UserTemplate define QUIÉN ES y QUÉ TIENE (anexo A.02 · MANUAL-USER-TEMPLATE) |
| División normada | `ROLES`+`PRMS` ↔ este contrato · `USERS` ↔ UserTemplate · `UA` ↔ asignación — ANSI INCITS 359 |
| Ciclo de vida | `DRAFT → REVIEW → ACTIVE → DEPRECATED → ARCHIVED` — REVIEW exige las N aprobaciones del B3; transiciones automáticas: expiración → DEPRECATED · sin usuarios → ARCHIVED · a DRAFT solo sin usuarios activos |
| Nomenclatura | `{DEPT}-{NN}` operativo · `{DEPT}-SUP-{NN}` supervisor · `{SIGLA}-{NN}` C-Level · `SVC-{APP}-{NN}` servicio · `AUD-{SCOPE}-{NN}` auditoría |
| Materialización actual | Tabla `bauth.idn_role_template` (548 roles, seed `bauth_48`) + closure (`bauth_62`) + catálogo de tipos (`bauth_47a`) |

---

## 3. B1 — Identificación y metadatos

**Propósito (del contrato):** identidad canónica, versionado semántico, jerarquía H-RBAC.
**Estándar declarado:** ANSI/INCITS 359 §4 (Role Hierarchy) · SemVer 2.0.

| Parte | Qué define | Origen normativo · estado de materialización |
|---|---|---|
| `id` | Identificador canónico **inmutable** post-creación (formato original `{SIGLA}-{NNN}`) | ISO 24760-2 §5.2 (único·persistente·no reutilizable) — **✅ G-B01-01:** `uuid DEFAULT uuidv7()` PK (RFC 9562; time-ordered, no enumerable) |
| `parent_id` | Herencia H-RBAC — el padre del que hereda; `null` = raíz; herencia con remoción (hijo = padre &^ bits removidos); jamás circular (validación DAG) | INCITS 359 §3.2 RBAC1 (partial order) — **✅ G-B01-02:** FK a sí misma `ON DELETE RESTRICT`; cadena completa en `idn_role_closure` |
| `type_id` | Clasificación del tipo de cuenta | NIST AC-2(a) — **✅ G-B01-03:** FK a catálogo `idn_role_type` (10 tipos NIST: INDIVIDUAL, EXTERNAL, GUEST, GROUP, SYSTEM, SERVICE, M2M, EMERGENCY, TEMPORARY, DEVELOPER) |
| `hierarchy_level` | Profundidad REAL del nodo en el árbol (no etiqueta empresarial) | INCITS 359 §3.3 — **✅ G-B01-04:** derivado con `WITH RECURSIVE` en `bauth_62` (548 roles, niveles 0–7) |
| `path_ids` | Cadena de ancestros raíz→rol — calculado, solo lectura | Materializado por la closure table |
| `version` | SemVer de la definición de ESTE rol — MAJOR = breaking en permisos | ISO 27001 A.8.32 · SemVer — **G-B01-06 en resolución:** columnas + CHECK ya en VPS (`bauth_47d`); historia → Motor de Versionado Universal (1.13) |
| `status` | Ciclo de gestión del rol como artefacto | NIST AC-2(j) — **✅ G-B01-05:** ENUM `role_status_type` (DRAFT/REVIEW/ACTIVE/SUSPENDED/DEPRECATED/ARCHIVED) |
| `name` / `description` | Multilenguaje obligatorio (es/en/pt) | i18n del contrato |
| `metadata` | Organización y territorio: department, cost_center, region, territory_code, job_family, job_level (escala I1-I5/M1-M5/D1-D3), max_subordinates, required_certifications[], reporting_line, **classification** (PUBLIC/INTERNAL/CONFIDENTIAL/RESTRICTED) | `classification` → ISO A.5.12 (**G-B01-07 pendiente**) |
| `audit` | Trazabilidad del artefacto: created/updated by+at, `version_number` (contador de UPDATEs) y **`change_history[]`** — cada entrada: `{version, date, changed_by, approved_by, changes[] (delta semántico), change_reason, security_impact}` | ISO A.8.15 — **el patrón de historial del contrato**: deltas semánticos, jamás copias. Materialización: `ver_history` del motor 1.13 (la fila viva no acumula su historia infinita) |
| `digital_signature` | Firma del contrato del rol: `algorithm` EdDSA_Ed25519 (NIST SP 800-186 §3.2.1) · post-cuántico planeado | Ley 164 · ADSIB (**G-B01-08 pendiente**) — motor dual en MANUAL-FIRMA |

---

## 4. B2 — Vigencia y ciclo de vida

**Propósito:** controlar el período de validez del rol (el eje de NEGOCIO — distinto del eje
registral del versionado; ver 1.13 §6 P7). **Estándar:** ISO 24760 §7 · NIST 800-63B §4.3.

| Parte | Qué define | Origen normativo · estado |
|---|---|---|
| `validity_period.type` | El tipo de vigencia gobierna la fecha de fin — no es decisión arbitraria | NIST AC-2(d) — **✅ G-B02-01:** ENUM `role_validity_type`: `INDEFINITE` (estructurales; se gestiona por review), `FIXED` (fin contractual, humano obligatorio), `PROJECT_BASED` (milestone, humano+notificación), `TEMPORARY` (creación+duración, **inextensible**), `EMERGENCY` (creación+72h fijas NIST AC-2(2), **inextensible**) |
| `start_date` / `end_date` / `duration_interval` | Fechas de vigencia con regla determinista por tipo | ISO A.5.18 §c — **✅ G-B02-02:** `start_date` automático; `end_date` por trigger según ENUM; CHECK de integridad tipo↔fecha |
| Comportamiento TEMPORARY/EMERGENCY | Todos los asignados comparten el tiempo de vida del rol: al vencer, de-asignación automática en la misma transacción | NIST AC-2(2) · ISO A.5.18 ("temporary access automatically revoked") |
| Reconcile (60 s) | INDEFINITE: auto-extensión si hay usuarios activos / consulta al owner si no · PROJECT_BASED: notificación 30 días antes, solo el humano decide · TEMPORARY/EMERGENCY: DEPRECATED inmediato + revocación + evento A.8.15 | Diseño G-B02-01 (el motor de reconciliación opera este eje) |
| `review_date` (G-B02-03) · `max_renewals` (G-B02-04) · `early_termination` (G-B02-05) | Revisión periódica · límite de renovaciones (anti privilege-creep) · aprobación para terminación anticipada | ISO A.5.18 · PCI 7.2.4 · NIST 800-63B §5.4 · AC-2(i) — **⏳ pendientes** |

---

## 5. B3 — Flujo de aprobación

**Propósito:** la gobernanza de cambios del propio contrato — **el artefacto define quién y
cómo aprueba sus cambios**. **Estándar:** ISO 27001 A.5.2 · gestión de cambios (CM-3/AC-5).

| Campo | Qué define | Detalle normativo |
|---|---|---|
| `required_approvers` | **Quórum N**: cuántas aprobaciones se necesitan | AC-5 dual control generalizado a N-de-M; validación: `required_approvers ≤ len(approver_roles)` (§18) |
| `approver_roles[]` | **De quiénes (M)**: los roles habilitados para aprobar este rol | PCI 7.2.5.1 ("authorized personnel", nivel ≥ solicitante) |
| `notification_channel` | Canal de notificación de la solicitud | Vía daemon de notificación (bNotify) — bAuth no envía directo |
| `sla_hours` (48) | Tiempo máximo antes de que la solicitud expire | ISO A.5.18 §b ("in a timely manner") |
| `escalation_after_hours` (24) / `escalation_to[]` | Escalación automática al siguiente nivel si no hay respuesta | NIST AC-2(e) — **G-B03-04/05** formalizan los campos |

**Consumidor directo:** el Motor de Versionado Universal implementa EXACTAMENTE este workflow
para los cambios MAJOR (1.13 §9.3 paso 4 y `ver_proposal`: quórum + `sla_deadline` +
`escalated`) — el motor lee la gobernanza del artefacto, no la inventa (1.13 P6).

---

## 6. B4 — Dominio lógico (autenticación digital)

**Propósito:** controla cómo y cuándo el usuario puede autenticarse digitalmente — el corazón
NIST 800-63B del contrato. **Estándar:** NIST SP 800-63B (AAL) · FIDO2/WebAuthn W3C · RFC 9470.

| Parte | Qué define | Detalle normativo verificado |
|---|---|---|
| `availableMethods[]` | El **pool** de autenticadores que el rol PODRÍA usar (no todos obligatorios): password, TOTP, HOTP, WebAuthn plataforma/roaming, passkey, X.509 smartcard, magic link, email OTP, push, backup codes, security questions (solo recuperación) | 800-63B §4 (categorías de authenticator). **`sms_otp` marcado DEPRECADO en el propio contrato** (800-63B Rev.4 §5.1) — solo legacy, reemplazo TOTP/passkey |
| `requiredMethods{}` | Combinaciones por **contexto de acceso**: `standard_login` (pwd+TOTP → LoA 2) · `elevated_login` (pwd+WebAuthn → LoA 3) · `financial_high_value` (pwd+WebAuthn+TOTP fresco, >25.000 BOB) | 800-63B §4.2: AAL por combinación de factores — verificado: el AAL pertenece a la sesión, por eso se define por contexto |
| `alternativeMethods[]` | Sustitutos del mismo AAL con condiciones: `{replaces, with, requires_approval, max_uses, reason}` | 800-63B §4 (equivalencia de nivel) |
| `level_of_assurance` | LoA base del rol (1=pwd, 2=MFA, 3=MFA fuerte, 4=WebAuthn+quórum) | **G-B04-03:** hoy campo declarado; la coherencia LoA(hijo) ≥ LoA(padre) es validación semántica (§18) |
| `step_up_rules[]` | Elevación DURANTE la sesión: `{trigger, condition_pyson, required_loa, max_age_seconds, acr_value}` — ej.: aprobar >10.000 BOB exige LoA 3 fresco (300 s); cambio de configuración exige `max_age 0` (autenticación fresca SIEMPRE) | RFC 9470 §3 (`acr_values`+`max_age`) — verificado |
| `geospatial_control` | Redes/ubicaciones lógicas permitidas (`office`/`vpn`/`home_office` con rangos CIDR), `requires_vpn`, `geo_velocity_check` (viaje imposible >1200 km/h, tolerancia 10 km) | NIST 800-207 §3.2 (la ubicación como atributo del sujeto). **Duplicado con B8 — consolidación en B17/D6 (plan §17)** |
| `temporal_control` | Horario laboral: `schedule_type` (FULL_WEEK/SPECIFIC_DAYS/ALTERNATE_DAYS), timezone IANA, turnos por día, excepciones (feriados BLOCKED/ALLOWED/REQUIRES_APPROVAL, fechas especiales, `emergency_override` con aprobadores y máx. 4 h) | NIST AC-2(d). **Migra a B15/D4 (plan §17)** |
| `session_management` | `max_session_duration_s` (8 h) · `inactivity_timeout_s` (15 min) · `force_logout_at_end_shift` · `concurrent_sessions_allowed` · `reauthentication_interval_s` (4 h) | 800-63B §7 — verificado: timeout total + inactividad + reautenticación son la estructura exacta del estándar |

`[pre-ADR-010]` El contrato indica la traducción original a flujos del motor externo; hoy los
flujos son nativos (`domain/auth_methods/` — MANUAL-AUTENTICACION).

---

## 7. B5 — Dominio físico (acceso presencial)

**Propósito:** acceso a espacios físicos, actuadores y hardware — materializado con las fichas
de dispositivo (bhnexus/banexus). **Estándar:** ISO 27001 A.7 · NIST 800-116 · SIA OSDP v2.2.

| Parte | Qué define | Detalle normativo |
|---|---|---|
| `availableMethods[]` | Credenciales físicas del pool: QR dinámico (HMAC-SHA256, TTL 30 s), NFC DESFire (AES-128, LoA 2), NFC Classic (solo legacy, LoA 1), RFID 125 kHz (baja seguridad), hash de huella/rostro (**jamás el biométrico crudo**; PBKDF2→Argon2id), smartcard X.509 (LoA 3-4), PIN (jamás factor único) | NIST 800-116 · ISO 30107 |
| `requiredMethods{}` | Por criticidad de zona: estándar (NFC LoA 2) · restringida (NFC+huella LoA 3) · crítica (smartcard+huella LoA 4) | A.7.2 (control por zona) |
| `zones[]` | Zonas accesibles con: `security_level` 1-4, `access_level` (FULL/READ_ONLY/TIMED con `max_duration_minutes`/ESCORTED/**DENIED explícito** — niega aunque la zona padre permita), horario, puntos de acceso | A.7.2 — default cerrado |
| `biometric_enrollment_policy` | Modo (admin_only/self_service/**hybrid**), liveness obligatorio (passive/active/combined), fallback tras N fallos, **Argon2id** (t=3, m=64 MB, p=2 — OWASP ASVS 2.4.3 / PHC 2015; PBKDF2/bcrypt/SHA1/MD5 deprecados), FMR 1:10.000 (LoA 2) / 1:100.000 (LoA 3) | ISO 30107-3 (PAD) · NIST 800-76-2 (calidad/FMR). **Migra a B16/D5 (plan §17)** |
| `physical_security_controls` | `two_person_rule` (bóvedas/datacenter) · `mantrap_required` · **`anti_passback`** (hard/soft, reset 24 h — impide entrar dos veces sin salir) | NIST 800-116 §5 (**G-B05-05** lo formaliza) |

---

## 8. B6 — Zonas de negocio

**Propósito:** en qué zonas organizacionales opera el rol y con qué verbos — la
materialización del permiso formal. **Estándar:** OASIS XACML 3.0 · NIST SP 800-162 (ABAC).

| Parte | Qué define | Detalle normativo |
|---|---|---|
| Estructura `zones{}` | Clave = zona ABSTRACTA de negocio (no la aplicación); las apps que implementan cada zona se resuelven en el mapa zona→aplicación (`zone_application_map`) — **la zona es el objeto, nunca la app** | INCITS 359 §3: `PRMS = (operación, objeto)` — verificado: la zona es el "objeto" del par formal |
| Verbos universales | `READ · WRITE · DELETE · APPROVE · EXECUTE · CONFIGURE · AUDIT · EMIT` — subconjunto validado contra el catálogo (§18) | MANUAL-VERBOS (1.02) |
| `scope` | `GLOBAL / REGIONAL / LOCAL / PERSONAL` — REGIONAL genera filtro de datos automático por territorio | NIST 800-162 (environment attribute) — **G-B06-03** |
| `restrictions` | `max_record_limit` · `data_classification[]` accesible (PUBLIC/INTERNAL/CONFIDENTIAL) · `pii_access` (activa logging extra + `masking_policy`, ej. `lastFourVisible`) | RGPD Art. 5(1)(b) · ISO 27701 — **G-B06-04** |
| Zonas financieras (`zone_financial/*`) | Además: `limit_tier` 0-5 (0=sin ops · 1=1k · 2=10k · 3=50k · 4=200k · 5=sin límite) · `sod_cannot_also` (ej.: quien crea/aprueba no audita) · `requires_dual_approval_above` · `currency` ISO 4217 | PCI 7.2.5 · SOX §302 — **G-B06-05** |

---

## 9. B7 — Privilegios ERP en 5 capas

**Propósito:** enforcement por capas en las aplicaciones de negocio. **Estándar:** NIST AC-3 ·
AC-6(10) · ISO A.8.11 · PCI 7.3. **Materialización vigente (ADR-010):** el enforcement de
autorización es **nativo** (BitMask + PolicyEngine — 1.09 §2.4/§12); el modelo de 5 capas
permanece como patrón declarativo de integración de aplicaciones del ecosistema (catálogo de
átomos D1 + aduana biedata — MANUAL-APLICACIONES 1.10). Los objetos nominales del ERP de época
viven solo en el traslado (§19).

| Capa | Qué controla | Ejemplo del contrato · norma |
|---|---|---|
| 1 `model_access` | CRUD por modelo de datos — `read:false` = invisible TODO el modelo | Regla notable: **ningún rol lee la tabla de usuarios** (aislamiento de privacidad) · AC-3 |
| 2 `visible_actions` | Menús/acciones visibles — lo no listado es INVISIBLE | AC-6(10): prohibir funciones no necesarias en la UI |
| 3 `field_restrictions` | Campos individuales: `margin`, `cost_price` ocultos; `credit_limit` solo lectura | ISO A.8.11 (data masking por rol) |
| 4 `button_rules` | Botones/aprobaciones con condición evaluable: `users_required` (1 ó 2), `condition_pyson` por monto, `sod_cannot_also` (quien creó el pago no lo aprueba), `step_up_loa` (WebAuthn para >10k) | PCI 7.3.1 · dual control — **conecta B4 (step-up) con B8 (límites)** |
| 5 `record_rules` | Filtros de fila automáticos en CADA consulta: solo la región del usuario, solo oportunidades propias, jamás registros de empleados internos | NIST 800-162 (resource attribute) — least privilege a nivel de fila |

---

## 10. B8 — Dominio financiero

**Propósito:** regula operaciones económicas, límites y aprobaciones. **Estándar:** PCI DSS
4.0 · ISO A.5.3 · NIST AC-5 · COBIT 2019.

| Parte | Qué define | Detalle normativo |
|---|---|---|
| `availableMethods[]` / `requiredMethods{}` | Autenticación ADICIONAL para operar: estándar (smartcard+token móvil) · alto valor (+biométrico) | PCI Req 8 (MFA para funciones financieras) |
| `transaction_schedule` | Ventanas de operación (`CONTINUOUS`/`SCHEDULED` — ej.: pagos a proveedores solo los días 13-15 y 28-31, 09:00-16:00) + `emergency_override` (aprobación FINANCE_DIRECTOR/CEO, máx. 2 h, auditoría critical) | NIST AC-2(d). **Duplicado con B2/B4 — consolida en B15/D4 (plan §17)** |
| `transaction_limits` | `currency` (ISO 4217) · `single_transaction_limit` · `daily_limit` · `monthly_limit` · `per_period_limit` · `requires_dual_approval_above` | PCI 7.3.1 · SOX §302 (**G-B08-01/02 ✅ en demo**) |
| `sod_rules[]` | SoD financiero evaluado por la Conflict Matrix ANTES de guardar asignaciones: crear⊥aprobar (ventas, pagos) con `severity: critical` | AC-5 · INCITS 359 SSD |
| `geospatial_control` | Restricción geográfica ESPECÍFICA para finanzas (solo oficina central, red segura, sin remoto) | 800-207. **Duplicado con B4 — consolida en B17/D6** |
| Facturación Bolivia | `rnnd_emisor` (habilitación SIAT como punto de emisión con NIT y modalidad) · `modalidad` (EN_LINEA/FUERA_DE_LINEA/MASIVA — **G-B08-05 ausente**) · `firma_electronica_required` (umbral legal → firma con validez jurídica) | SIN RND 102100000011 §4-5 · Ley 164 Art. 78 |

---

## 11. B9 — SAM-128 + BitMask (calculado)

**Propósito:** la representación binaria de la autoridad, calculada por el PrivilegeEngine —
**READONLY: jamás se edita a mano; jamás genera versión humana** (1.13 P9).

| Parte | Qué es | Estado |
|---|---|---|
| `bitmask_64_ref` | El BitMask 64-bit del catálogo: capa 1 [31:0] sistema · capa 2 [63:32] negocio; máscara efectiva = propia OR la de todos los junior (herencia DAG) | MANUAL-BITMASK (1.04) · BAUTH-CATALOGO-ROLES-EMPRESARIALES §6 |
| `*_domain_mask_hex` (Q1–Q4) | SAM-128: cuadrantes lógico/físico/financiero/gobernanza (32 bits c/u) | **G-B09-01/02: ✗ no calculado** — en el demo son valores estáticos; el plan corregido vive en `SBOS-BITMASK-ANALISIS-SAM128-Y-PLAN-CORREGIDO` |
| `computed_at` / `computed_by` | Sello del cálculo | PrivilegeEngine |

> **Corrección vigente (jun-2026):** las operaciones de herencia/combinación usan el **Rol
> BitMask (one-hot)**, NUNCA el BitMask Átomo (label encoding) — la distinción ortogonal es
> regla absoluta (MANUAL-BITMASK · ADR-009).

---

## 12. B10 — Delegación (DSD)

**Propósito:** cómo el rol delega permisos temporalmente — el componente **DSD** del estándar
RBAC. **Estándar:** INCITS 359 §4.2 (Dynamic SoD) · NIST AC-6(3) · ISO A.5.17 · RFC 8693.

| Campo | Qué define | Norma |
|---|---|---|
| `can_delegate` · `delegable_to_roles[]` | Solo hacia roles listados (jamás hacia arriba) | AC-6(3) |
| `max_duration_days` (21) · `auto_revoke_on_expiry` | La delegación jamás es permanente; revocación automática | ISO A.5.17 |
| `non_delegable_permissions[]` | Lista negra absoluta (configurar reportes, aprobar ventas, administrar usuarios) | AC-6(3) — el corazón anti-escalada |
| `requires_approval` + `approver_roles[]` | Aprobación previa del supervisor | AC-5 (**G-B10-05**) |
| `max_concurrent_delegations` (1) | Limita el encadenamiento — máx. profundidad 2 validada (§18) | INCITS 359 DSD (evita reconstruir un permiso prohibido por delegaciones sucesivas) |
| `notification_channels[]` | Aviso por el daemon de notificación | — |
| Token de delegación | El intercambio conserva al `actor` original para auditoría | RFC 8693 Token Exchange (**G-B10-06** lo formaliza) |

---

## 13. B11 — Grupos y jerarquías (RBAC1)

**Propósito:** herencia, grupos funcionales y composición — el componente **Hierarchical** del
estándar. **Estándar:** INCITS 359 §3.2 RBAC1 · NIST AC-2(g).

| Parte | Qué define | Detalle |
|---|---|---|
| `role_hierarchy` | `level` · `parent_role` · `child_roles[]` — con `inheritance_rules`: heredar permisos + **`bits_removed_from_parent[]`** (el hijo = padre &^ removidos: hereda ventas pero NO configuración ni administración de usuarios) + `permission_modifications` (ej.: el padre tiene `FIN_LIMIT_TIER 3` (50k), el hijo hereda `2` (10k)) | RBAC1 partial order con **herencia sustractiva controlada** — materializada en `parent_id` + closure + máscaras (B9) |
| `role_groups[]` | Grupos funcionales: `group_type` FUNCTIONAL, miembros, permisos compartidos y **`quorum_requirements`** (ventas de alto valor: 2 miembros activos; cambios de política: 3) | AC-2(g) (**G-B11-04**) · PCI 7.2.5 (**G-B11-05** — aprobación k-de-n) |

---

## 14. B12 — Gestión de conflictos (SSD/SoD)

**Propósito:** prevenir fraude por separación formal de funciones — el componente **SSD** del
estándar. **Estándar:** INCITS 359 SSD · NIST AC-5 · ISO A.5.3 · COBIT 2019.

| Parte | Qué define | Detalle |
|---|---|---|
| `incompatible_roles[]` | Roles que NO pueden coexistir en el mismo usuario (ej.: gerente de ventas ⊥ auditor financiero) con `severity` y `mitigation` (**DENY** bloquea · APPROVE exige aprobación especial documentada) | AC-5 · SSD (constraint en tiempo de ASIGNACIÓN — verificado: así lo define el estándar) |
| `incompatible_functions[]` | Pares función_a ⊥ función_b (crear⊥auditar transacciones) | AC-5 |
| `conflict_validation` | `check_frequency: REAL_TIME` — en cada solicitud de acceso y cada cambio de rol; alcance: conflictos DIRECTOS + HEREDADOS + POR DELEGACIÓN | Diferenciador bAuth: SoD en el momento, no batch nocturno (carta rectora §5) |
| `interest_conflicts` | Conflictos de interés: entidades restringidas (proveedores con relación familiar hasta 2º grado), declaración ANUAL obligatoria con verificación de cumplimiento | SOX §302 · COBIT (**G-B12-05** formaliza el proceso de excepción) |

---

## 15. B13 — Cumplimiento y auditoría

**Propósito:** trazabilidad y cumplimiento POR ROL. **Estándar:** ISO A.8.15 · RGPD Art. 30 ·
SOX §404 · PCI Req 10.

| Parte | Qué define | Detalle |
|---|---|---|
| `review_frequency` | MONTHLY/QUARTERLY/SEMIANNUAL/ANNUAL + fechas last/next | PCI 7.2.4 (trimestral para privilegiados) · ISO A.5.18 |
| `review_scope[]` | Qué se revisa: patrones de acceso, uso de permisos, historial de delegaciones, violaciones de conflicto, transacciones financieras | AU-2 |
| `reviewers[]` | Tres líneas: negocio + compliance + auditoría interna | AC-5 |
| `regulatory_frameworks` | Por marco: PCI (Req 7/8/10 con evidencia: access_logs, sod_matrix, mfa_enforcement) · RGPD (pii_access, `legal_basis`, minimización, `retention_days` 365) | Compliance como dato (MANUAL-NORMAS §2) |
| `access_review_policy` | SLA de revisión (14 días) + escalación (CISO/HR) + `auto_revoke_on_review_failure` | AC-2(j) |
| `change_tracking` | Elementos rastreados (PERMISSIONS, AUTHENTICATION_METHODS, TEMPORAL_ACCESS, DELEGATIONS, FINANCIAL_LIMITS, SOD_RULES) + **`retention_years: 7`** (registros financieros) | ISO 27001 + SOX — coherente con el régimen fiscal del calendario de retención (1.13 §10.1 · 2.10 §8) |

---

## 16. B14 — Estado de sincronización (calculado)

**Propósito:** rastrear la coherencia entre lo declarado y lo materializado — **READONLY del
reconcile loop; jamás versión humana** (1.13 P9).

| Parte | Qué es |
|---|---|
| `sync_status` | `PENDING / SYNCING / SYNCED / ERROR / DRIFT` — el semáforo del reconcile |
| `sync_targets` | `[pre-ADR-010]` El contrato v6.0 lista los destinos de la época; hoy la coherencia interna es BitMask + closure + políticas (MANUAL-ROLES §7.3) |
| `drift_detected` / `drift_details` | Divergencia declarado-vs-real → autocorrección o alerta |

---

## 17. La estructura COMPLETA por dominios — cobertura D00–D13 y los bloques por incorporar

**Principio de completitud (decisión del humano, 2026-07-11):** todos los planos de control del
sistema deben estar representados en la estructura del rol. La taxonomía canónica de planos es
la de MANUAL-DOMINIOS (1.01 §4): **D00–D13** (+ D99 fuera del BitMask; D14/D15 reservados).

### 17.1 Matriz de cobertura — los 14 planos contra la estructura del rol

Consolida PR-1 del SSOT + la tabla maestra de 1.01 §4:

| Plano (1.01) | Path de evaluación | Dónde vive HOY en el rol | Estado | Resolución |
|---|---|---|:---:|---|
| **D00** Identidad Organizacional | Pre-condición estructural (ctx_id) | B1 `metadata` (department, region, job_family, classification) | ⚠️ implícito | **Enriquecer B1** (§17.3-D0) — sin bloque nuevo |
| **D1** Acceso Lógico | Fast-Path <0.5 ns | **B4** completo | ✅ | — |
| **D2** Acceso Físico | Fast-Path (+OSDP) | **B5** completo | ✅ | — |
| **D3** Financiero | Policy-Path | **B8** completo (+B6 zonas financieras) | ✅ | — |
| **D4** Temporal | Policy-Path — **sin átomos propios: se encadena a D1** (1.01 §5.2) | Disperso: B2 (vigencia del rol) + B4 `temporal_control` (horario de autenticación) + B8 `transaction_schedule` (ventanas de transacción) | ⚠️ disperso | **Cross-refs `d4_temporal_ref`** entre B2/B4/B8 (§17.3-D4) — los tres responden preguntas distintas y legítimas; no se fusionan, se enlazan |
| **D5** Biométrico | External-Path | Embebido: B5 `biometric_enrollment_policy` | ⚠️ embebido | **Enriquecer B5** con ISO 30107-3 (§17.3-D5) — permanece en B5, completo |
| **D6** Geoespacial | External-Path — **sin átomos propios: encadenado a D1** | **Duplicado** en B4 y B8 (`geospatial_control` ×2 = dos fuentes de verdad) | ⚠️ duplicado | **Nuevo B15 `geospatial_policy`** — única fuente (§17.2-B15) |
| **D7** Red | External-Path (vía gateway) | **AUSENTE** — solo `network_ranges` dentro del control geoespacial | ❌ | **Nuevo B16 `network_access`** (§17.2-B16) |
| **D8** Contexto/Sesión | **Pre-BitMask** (¿ctx_id vivo?) | Parcial: solo `step_up_rules` en B4 | ⚠️ incompleto | **Nuevo B17 `adaptive_context`** (§17.2-B17) |
| **D9** Credenciales | **Pre-BitMask** (¿LoA suficiente?) | Parcial: solo `availableMethods` en B4 — sin ciclo de vida | ⚠️ incompleto | **Nuevo B18 `credential_lifecycle`** (§17.2-B18) |
| **D10** Delegación | Policy-Path (reducción AND) | **B10 + B11 + B12** completos | ✅ | — |
| **D11** Auditoría | **Post-hoc** (registra, no decide) | **B13** + `audit` de B1 | ✅ | — |
| **D12** Blockchain/Anclaje | External-Path | Parcial: solo `digital_signature` en B1 (firma DEL contrato ≠ operar en cadena) | ⚠️ incompleto | **Nuevo B19 `blockchain_access`** (§17.2-B19) |
| **D13** Firma Digital Externa | (diseño — átomos 5929–5964) | `ley164_compliance` aparecía DENTRO de B19 | ✅ resuelto | **Nuevo B20 `legal_signature_policy`** (§17.4-1) — separado de D12; el sujeto porta el certificado (A.02 §19.2-U6) |
| **D99** Administrativo Global | Fuera del BitMask (garante) | No aplica al rol: es el piso irrenunciable del sistema (2.06) | ✅ por diseño | — |

**Con el plan aplicado:** **14 de 14 planos representados** en la estructura del rol (6 ya
completos + 3 enriquecimientos + 6 bloques nuevos B15–B20, incluida la resolución D13 de
§17.4-1) — completitud verificada contra la taxonomía canónica de 1.01 §4.

### 17.2 Los cinco bloques nuevos — especificación de estructura (PR-2/PR-3 del SSOT)

> Estado: **PROPUESTA del plan de reparación del SSOT** — todo cambio al contrato v6.0 exige
> aprobación HITL (PR-5). Prioridades del SSOT: B15/B16 🔴 ALTA · B17/B18 🟠 MEDIA · B19 🟡 BAJA.

**B15 `geospatial_policy` (D6) — la única fuente de verdad geoespacial:**

| Parte | Qué define |
|---|---|
| `allowed_locations[]` | ÚNICA lista de ubicaciones/redes (extraída de B4+B8) — elimina la doble fuente de verdad |
| `validation_rules` | require_vpn, allow_roaming, viaje imposible (velocidad/tolerancia) |
| `financial_override` | Endurecimiento SOLO para operaciones financieras (red segura, sin remoto); `null` = hereda las reglas base |
| `gps_attestation` | Para métodos con GPS: exactitud máxima (metros), proveedor de atestación |
| En B4 y B8 | Queda la referencia `geospatial_ref` — jamás una copia |

Normas: NIST 800-207 §3.2 · NIST 800-162 · OGC GeoFence (1.01 §4) · LBAC.

**B16 `network_access` (D7) — el plano ausente:**

| Parte | Qué define |
|---|---|
| `zero_trust_mode` | Nunca confiar, siempre verificar (800-207) |
| `device_compliance` | Postura de dispositivo requerida (`managed`, `patched`, `encrypted`) y quién la verifica (el PEP del gateway) |
| `allowed_ranges[]` | CIDR por tipo (office/vpn/any+requires_vpn) — se extrae del control geoespacial actual |
| `mtls_required` | Certificado de cliente por request (RFC 8705) |
| `api_gateway_rules` | rate_limit_rpm, orígenes, plugins del gateway |
| `network_segmentation` | VLAN / micro-segmentación |

Normas: NIST SP 800-207 §2.2 · IEEE 802.1X · RFC 8705 · patrones de acceso condicional y
device-posture de la industria (PR-6).

**B17 `adaptive_context` (D8) — de triggers puntuales a evaluación continua:**

| Parte | Qué define |
|---|---|
| `risk_engine` | Proveedor interno, `evaluation_mode: continuous` (no solo al login), `revoke_on_anomaly`, intervalo de evaluación |
| `context_signals` | device_posture · user_behavior (baseline) · threat_intel · impossible_travel (cross-ref D6) · new_device · time_of_day (cross-ref D4) |
| `adaptive_policies[]` | Por umbral de riesgo: score >0.7 → step-up LoA 3 · score >0.9 → block + notificación |
| `emergency_access` | Break-glass con condiciones (dual approval), máx. 4 h, auditoría crítica |

Normas verificadas: NIST 800-207 §2.1 (Policy Engine) · RFC 9470 · **OpenID CAEP 1.0 (spec
final)** — los event types confirmados en la especificación: `session-revoked`,
`credential-change` (creada/cambiada/revocada/eliminada), `device-compliance-change`,
`assurance-level-change` (sube o baja el nivel desde el login inicial) — exactamente las
señales que bAuth ya emite/consume vía su cliente CAEP (MANUAL-BAUTH-BNOTIFY).

**B18 `credential_lifecycle` (D9) — el ciclo de vida que faltaba:**

| Parte | Qué define |
|---|---|
| `enrollment_policy` | Nivel de verificación **IAL1/2/3**, aprobación de supervisor, canales, `binding_type` (800-63B-4 §6.1.2) |
| `rotation_policy` | Password: **SIN rotación forzada** (800-63B-4 la eliminó) + `trigger_on_breach` obligatorio · TOTP: al cambiar dispositivo · X.509: 365 días con auto-renovación |
| `revocation_policy` | Inmediata al terminar (<30 s) · suspensión de gracia (7 días, permite reintegro) · canales de propagación (bóveda + gateway) |
| `privilege_creep_detection` | Revisión cada 90 días; umbral de permisos no usados (30%) → alerta |
| `recovery_policy` | Canales, verificación de identidad requerida (IAL), máx. intentos |

Normas: NIST 800-63B-4 §6 (Authenticator Lifecycle) · §5.1.1 · ISO 24760-2 §7 · OWASP ASVS
§2.1-2.5. **Regla absoluta preservada:** las credenciales JAMÁS en atributos — viven en la
bóveda (§7 de este anexo · NRS-10).

**B19 `blockchain_access` (D12) — operar en la cadena (distinto de firmar el contrato):**

| Parte | Qué define |
|---|---|
| `enabled` | `false` por defecto — la mayoría de los roles no opera en cadena (default cerrado) |
| `network` | Cadena soberana (Besu QBFT), chain_id, acceso SIEMPRE vía el daemon de conectividad — jamás directo |
| `signing_config` | ECDSA secp256k1 para la EVM, clave gestionada por la bóveda (path por rol) |
| `ley164_compliance` | Si la operación exige validez jurídica: certificado ADSIB + RND facturación |
| `smart_contract_permissions[]` | Por contrato y función (ej.: `AuditLog.appendEntry` — append-only) |
| `on_chain_audit` | Qué eventos del rol se anclan (aprobaciones de alto valor, cambios de rol) |
| `wallet_policy` | Rotación al compromiso, límite de valor por transacción |

Normas: ANSI X9.62 (ECDSA) · RFC 8032 · EIP-155 · NIST IR 8202 · Ley 164 Art. 13 · ADSIB.

### 17.3 Los tres enriquecimientos (sin bloque nuevo)

| Dominio | Acción sobre la estructura | Campos nuevos (PR-2) |
|---|---|---|
| **D0 → B1 `metadata`** | Formalizar la identidad organizacional del rol | `org_unit_id` (unidad canónica, no solo nombre) · `tenant_id` · `sector_code` (CAEB SIN, 21 sectores) · `accountability_chain` (cadena de responsabilidad hasta el CEO) · `data_owner_roles` (custodios de los datos que el rol maneja) — ISO 24760-2 §5 |
| **D4 → cross-refs** | Los tres tiempos NO se fusionan (responden preguntas distintas: ¿hasta cuándo existe el rol? B2 · ¿cuándo se autentica? B4 · ¿cuándo transacciona? B8) — se enlazan con `d4_temporal_ref` para una lectura de dominio única | GTRBAC · RFC 5545 · ISO 8601 (1.01 §4). Nota: D4 se evalúa encadenado a átomos D1 (PolicyChainResolver — 1.01 §5.2) |
| **D5 → B5 `biometric_enrollment_policy`** | Completar el embebido | `biometric_types_enrolled[]` (huella/iris/rostro/voz) · `cross_modality_policy` (modalidad alternativa) · `biometric_consent` (RGPD Art. 9 — dato sensible) · `template_storage` (on-device / server-side cifrado / federado) · `iso_30107_pad_level` (PAD 1/2/3) |

### 17.4 Verificación de completitud — hallazgos RESUELTOS

1. **D13 ausente del plan del SSOT → RESUELTO: parte propia `B20 legal_signature_policy` (D13).**
   El PR cubría D0–D12, pero MANUAL-DOMINIOS declara D13 — Firma Digital Externa — como plano
   diseñado (átomos 5929–5964). La firma legal existe SIN blockchain (ADSIB firma documentos,
   no bloques — MANUAL-FIRMA 2.04 distingue los dos motores; **eIDAS: el certificado
   cualificado pertenece a la PERSONA firmante**). Especificación del bloque del ROL:

   | Parte de B20 | Qué define |
   |---|---|
   | `enabled` | `false` por defecto (default cerrado) |
   | `operations_requiring_legal_signature[]` | Qué operaciones del rol exigen firma con validez jurídica (por zona:verbo y/o umbral de monto — enlaza B6/B8) |
   | `required_engine` | `INTERNAL` (Ed25519 — velocidad, integridad) o `EXTERNAL_ADSIB` (RSA-SHA256 — validez jurídica plena, Ley 164 Art. 78) — los dos motores de 2.04 |
   | `certificate_requirements` | Tipo/política del certificado exigido al firmante (ADSIB-FD-POLT-015) y verificación de vigencia previa a la operación |
   | `signature_evidence` | Qué se ancla como evidencia (hash del documento + sello de tiempo + `aud_event`) |

   La contraparte del SUJETO (quién porta el certificado y la wallet) quedó especificada en
   **A.02 §19.2-U6** (`legal_signature_identity`) — el rol define CUÁNDO se exige; el sujeto
   porta CON QUÉ firma. Los dos se materializan juntos en la revisión del contrato.
2. **Numeración doble B15–B21 → RESUELTO:** la canónica de bloques del contrato es la del SSOT
   (B15–B19 + B20 de este anexo); los códigos G-B* del doc de gaps son tracking, no bloques.
3. **B14 `sync_targets` de época → RESUELTO POR LOS MANUALES:** bajo ADR-010 el estado de
   sincronización es la **coherencia interna** (BitMask + closure + políticas — MANUAL-ROLES
   §7.3), y la verificación contra sistemas externos sobrevive solo como prueba de
   consistencia opcional (patrón canónico de 1.08 §7.2). La lectura §16 de este anexo lo
   refleja; los destinos nominales quedan solo en el traslado histórico (§19).

### 17.5 El árbol completo y la secuencia de incorporación (PR-4/PR-5 del SSOT)

```
role: {
  B1  IDENTIFICACIÓN [+D0 enriquecido] · B2 VIGENCIA [D4] · B3 APROBACIÓN [gobernanza]
  B4  D1 LÓGICO [+refs D4/D6/D8] · B5 D2 FÍSICO [+D5 completo] · B6 ZONAS [D1+D3]
  B7  PRIVILEGIOS ERP [D1 — 5 capas] · B8 D3 FINANCIERO [+refs D4/D6]
  B9  SAM-128 [READONLY — todos los dominios] · B10 D10 DELEGACIÓN · B11 GRUPOS
  B12 SOD · B13 D11 AUDITORÍA · B14 SYNC [READONLY]
  ── nuevos (materialización HITL): B15 D6 GEOESPACIAL · B16 D7 RED · B17 D8 CONTEXTO ·
                    B18 D9 CREDENCIALES · B19 D12 BLOCKCHAIN · B20 D13 FIRMA LEGAL (§17.4-1)
}
```

Secuencia del SSOT ampliada (la materialización de cada paso es HITL): D0 → D5 → B15 → B16 →
B17 → B18 → B19 → **B20 (D13)** → cross-refs D4 → recálculo SAM-128 (B9 con los dominios
nuevos) → lectura nativa de B14 (§17.4-3).

**Relación con el pipeline (1.01 §5):** la estructura alimenta la evaluación en su orden real —
Pre-BitMask (D8 ctx vivo → D9 LoA) → Fast-Path (D1→D2, <0.5 ns) → Policy-Path (D3→D10→D4) →
External (D6→D7→D5→D12) → **D11 siempre, post-hoc**. El cortocircuito detiene en el primer
DENY; nadie paga una verificación biométrica si el ctx_id ya expiró.

---

## 18. Las validaciones del contrato

**De esquema (JSON Schema 2020-12):** formato de `id` · existencia del `parent_id` ·
`end_date` obligatoria y posterior si FIXED · `limit_tier` 0-5 · `required_approvers ≤
len(approver_roles)` · formato SoD `modelo.boton:accion` / `zona:VERBO`.

**Semánticas (runtime, PrivilegeEngine):**

| Regla | Qué garantiza |
|---|---|
| DAG check | Sin ciclos en la herencia |
| Conflict Matrix | SoD evaluada ANTES de guardar |
| LoA coherence | LoA(rol) ≥ LoA(padre) |
| Zone verb consistency | Verbos ⊆ verbos universales |
| SAM-128 bounds | Ningún bit > 127 |
| Delegation depth | Máx. 2 niveles encadenados |

---

## 19. Traslado fiel — la estructura JSONB completa del contrato v6.0

> **Por qué esta sección existe (decisión del humano, 2026-07-11):** los anexos son la NUEVA
> documentación de bAuth — la documentación de origen ya no será fuente de consulta. Por eso
> este anexo contiene la estructura COMPLETA del contrato, trasladada fielmente (extracción
> literal, no transcripción). Las secciones §3–§16 son su lectura normativa; esta sección es
> el artefacto íntegro. Origen histórico (solo cita, no lectura): `SBOS-ROLTEMPLATE-v6_0`.

### 19.1 La estructura de los 14 bloques (íntegra)

```json
{
  "role": {

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 1 — IDENTIFICACIÓN Y METADATOS
    // Propósito: Identidad canónica, versionado semántico, jerarquía H-RBAC
    // Estándar: ANSI/INCITS 359-2004 §4 (Role Hierarchy), SemVer 2.0
    // ═══════════════════════════════════════════════════════════════════

    "id": "RGV-001",
    // ID canónico — INMUTABLE post-creación.
    // Formato: {SIGLA_DEPARTAMENTO}-{NUM_3_DIGITOS}
    // Este mismo ID se usa como: Composite Role en KC, Grupo en Tryton.
    // Ejemplos: DGV-001, RGV-001, VEN-VEN-001, CFO-001, IT-ADM-001

    "parent_id": "VEN-BASE-001",
    // Referencia al RolTemplate padre para herencia H-RBAC.
    // null = rol raíz (sin herencia).
    // Herencia vía AND NOT: hijo = padre &^ bits_removidos.
    // NUNCA circular (bAuth valida DAG antes de guardar).

    "type_id": "TYPE-GERENCIA-REGIONAL",
    // Clasificación funcional del rol.
    // Valores sugeridos: TYPE-OPERATIVO, TYPE-SUPERVISOR, TYPE-GERENCIA-MEDIA,
    //   TYPE-DIRECCION, TYPE-ADMIN-SISTEMA, TYPE-SERVICIO, TYPE-AUDITORIA

    "hierarchy_level": 2,
    // Nivel en la jerarquía organizacional (1=más alto, N=más bajo).
    // 1 = C-Level/Dirección, 2 = Gerencia regional, 3 = Supervisor,
    // 4 = Operativo calificado, 5 = Operativo estándar

    "path_ids": ["VEN-BASE-001", "RGV-001"],
    // Cadena completa de ancestros desde raíz hasta este rol.
    // Calculado automáticamente por bAuth. Solo lectura.

    "version": "3.1.0",
    // Versión semántica del contrato de este rol.
    // MAJOR.MINOR.PATCH — cambio MAJOR = breaking change en permisos

    "status": "ACTIVE",
    // DRAFT      → en diseño, no sincronizado
    // REVIEW     → pendiente aprobación del ARB
    // ACTIVE     → sincronizado en KC + Tryton, operativo
    // DEPRECATED → operativo pero no asignable a nuevos usuarios
    // ARCHIVED   → desactivado, sin sesiones activas posibles

    "name": {
      // Nombre multilenguaje (i18n obligatorio).
      "es": "Gerente Regional de Ventas — Región Norte",
      "en": "Regional Sales Manager — Northern Region",
      "pt": "Gerente Regional de Vendas — Região Norte"
    },

    "description": {
      "es": "Responsable de operaciones comerciales en la región norte. Gestiona equipo de hasta 10 vendedores, aprueba ventas hasta 50.000 BOB, administra cartera de clientes asignada.",
      "en": "Responsible for commercial operations in the northern region.",
      "pt": "Responsável pelas operações comerciais na região norte."
    },

    "metadata": {
      // Datos organizacionales y territoriales del rol.
      "department":             "Ventas",
      "cost_center":            "VEN-NORTE",
      "region":                 "NORTH",
      "territory_code":         "VEN-NORTH-001",
      "job_family":             "Sales",
      "job_level":              "M2",
      // job_level según escala interna: I1-I5 (individual), M1-M5 (manager), D1-D3 (director)
      "max_subordinates":       10,
      "required_certifications":["SALES_CERT_A", "MANAGEMENT_CERT_B"],
      "reporting_line":         "SALES_DIVISION",
      "classification":         "CONFIDENTIAL"
      // CONFIDENTIAL | RESTRICTED | INTERNAL | PUBLIC
    },

    "audit": {
      // Trazabilidad completa de creación y modificación (ISO 27001 A.8.15).
      "created_by":   "ADMIN.SISTEMA",
      "created_at":   "2024-01-01T00:00:00Z",
      "updated_by":   "DGV.CARLOS.RUIZ",
      "updated_at":   "2026-03-01T10:30:00Z",
      "version_number": 7,
      // Incrementa en cada UPDATE. Auditado en bos_rol_template_history.
      "change_history": [
        {
          "version":      "3.1.0",
          "date":         "2026-03-01T10:30:00Z",
          "changed_by":   "DGV.CARLOS.RUIZ",
          "approved_by":  "CFO",
          "changes":      ["Incremento límite financiero L1 de 40k a 50k BOB"],
          "change_reason":"Ajuste por inflación anual — Resolución DIR-2026-003",
          "security_impact":"LOW"
        }
      ]
    },

    "digital_signature": {
      // Firma digital del contrato — asegura integridad del RolTemplate.
      "signature":            "base64_encoded_EdDSA_signature",
      "algorithm":            "EdDSA_Ed25519",
      // Algoritmo primario: EdDSA (alta seguridad, rendimiento óptimo).
      // NIST SP 800-186 §3.2.1 recomienda Ed25519 para nuevas implementaciones.
      "post_quantum_planned": "CRYSTALS-Dilithium",
      // Algoritmo post-cuántico planeado (NIST PQC Standard 2024).
      // Se activará en modo híbrido EdDSA+Dilithium cuando Vault 2.0+ lo soporte.
      // Release planeado: 2027-2028.
      "certificate_thumbprint":"sha256:abc123...",
      "timestamp":            "2026-06-20T10:31:00Z",
      "validity": {
        "not_before": "2026-06-20T10:31:00Z",
        "not_after":  "2027-06-20T10:31:00Z"
      }
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 2 — VIGENCIA Y CICLO DE VIDA
    // Propósito: Controlar período de validez del rol
    // Estándar: ISO/IEC 24760 §7 (Identity Lifecycle), NIST SP 800-63B §4.3
    // ═══════════════════════════════════════════════════════════════════

    "validity_period": {
      "type":       "FIXED",
      // FIXED         → requiere start_date y end_date
      // INDEFINITE    → sin caducidad (end_date = null)
      // PROJECT_BASED → vigencia vinculada a un proyecto específico

      "start_date": "2026-01-01T00:00:00Z",
      "end_date":   "2027-12-31T23:59:59Z",
      // null para INDEFINITE. bAuth valida automáticamente al expirar.

      "review_date":"2026-07-01T00:00:00Z",
      // Fecha de revisión periódica (Quarterly|Semiannual|Annual).
      // bAuth alerta 30 días antes al role_owner.

      "renewal_settings": {
        "renewable":              true,
        "max_renewals":           2,
        "renewal_duration_days":  365,
        "auto_renewal":           false,
        // Si true, bAuth renueva automáticamente sin aprobación.
        "renewal_approval_roles": ["DIRECTOR_VENTAS", "COMPLIANCE_OFFICER"]
      },

      "early_termination": {
        "allowed":             true,
        "requires_approval":   true,
        "approver_roles":      ["DIRECTOR_VENTAS", "HR_DIRECTOR"],
        "notice_period_days":  5,
        "documentation":       "mandatory"
      }
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 3 — FLUJO DE APROBACIÓN
    // Propósito: Gobernanza de cambios al RolTemplate
    // Estándar: ISO/IEC 27001 A.5.2 (Policies), ITIL Change Management
    // ═══════════════════════════════════════════════════════════════════

    "approval_workflow": {
      "required_approvers":    2,
      "approver_roles":        ["DIRECTOR_VENTAS", "CFO"],
      // Mínimo required_approvers de approver_roles deben aprobar.
      // bAuth valida: required_approvers <= len(approver_roles).
      "notification_channel":  "rocket_chat",
      // rocket_chat | email | slack
      "sla_hours":             48,
      // Tiempo máximo para obtener aprobación antes de expirar el request.
      "escalation_after_hours":24,
      // Si no hay respuesta en N horas, escalar al siguiente nivel.
      "escalation_to":         ["CISO", "CEO"]
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 4 — DOMINIO LÓGICO (Autenticación Digital)
    // Propósito: Controla cómo y cuándo el usuario puede autenticarse digitalmente.
    // bAuth traduce este bloque a → Authentication Flow KC + User Attributes.
    // Estándar: NIST SP 800-63B AAL, FIDO2/WebAuthn W3C, RFC 9470 Step-Up
    // ═══════════════════════════════════════════════════════════════════

    "logical_access": {

      "availableMethods": [
        // Lista COMPLETA de métodos que el sistema soporta y que este rol PODRÍA usar.
        // No todos son obligatorios — ver requiredMethods.
        "username_password",
        "totp",
        "hotp",
        "webauthn_platform",
        // WebAuthn con authenticator de plataforma (Face ID, Windows Hello, Touch ID)
        "webauthn_roaming",
        // WebAuthn con hardware key (YubiKey, Nitrokey)
        "passkey",
        // Passkeys sincronizadas (FIDO2 con sync, KC 26.4+)
        "x509_smartcard",
        // Certificado X.509 en tarjeta inteligente (PIV)
        "magic_link",
        // Email magic link (single-use, TTL 5 min)
        "email_otp",
        // OTP enviado a email (KC 26 nativo)
        "push_notification",
        // Push a app móvil (requiere SPI externo)
        "sms_otp",
        // ⚠️ DEPRECADO por NIST SP 800-63B Rev.4 §5.1 — NO USAR para nuevos roles.
        // Solo mantenido para roles legacy que aún no han migrado a TOTP/Passkey.
        // Reemplazo: TOTP (KC_TOTP) o Passkey (KC_PASSKEY).
        "backup_codes",
        // Códigos de recuperación de un solo uso
        "security_questions"
        // Solo para recuperación de cuenta — NUNCA como factor primario
      ],

      "requiredMethods": {
        // Define qué combinación de factores se necesita según el contexto de acceso.
        // Cada entry es un Authentication Flow distinto en KC.
        "standard_login": [
          {"method": "username_password", "order": 1, "required": true},
          {"method": "totp",              "order": 2, "required": true}
        ],
        // Login estándar: pwd + TOTP. LoA 2.

        "elevated_login": [
          {"method": "username_password",  "order": 1, "required": true},
          {"method": "webauthn_platform",  "order": 2, "required": true}
        ],
        // Login elevado: pwd + biométrico digital. LoA 3.
        // Se activa por step-up desde operaciones de alto riesgo.

        "financial_high_value": [
          {"method": "username_password",  "order": 1, "required": true},
          {"method": "webauthn_platform",  "order": 2, "required": true},
          {"method": "totp",               "order": 3, "required": true}
        ]
        // Para transacciones > 25.000 BOB. LoA 3 + TOTP fresco.
      },

      "alternativeMethods": [
        // Sustitutos permitidos si el método requerido no está disponible.
        {
          "replaces":          "webauthn_platform",
          "with":              "webauthn_roaming",
          "requires_approval": false,
          "reason":            "Dispositivo sin biométrico nativo"
        },
        {
          "replaces":          "totp",
          "with":              "backup_codes",
          "requires_approval": true,
          "max_uses":          1,
          "reason":            "Pérdida de dispositivo TOTP"
        }
      ],

      "level_of_assurance": 2,
      // LoA requerido base para este rol.
      // 1 = password simple, 2 = MFA (pwd+OTP), 3 = MFA fuerte (WebAuthn/biométrico), 4 = WebAuthn+quórum

      "step_up_rules": [
        // Define cuándo se requiere autenticación adicional durante la sesión (RFC 9470).
        {
          "trigger":          "financial_approve",
          "condition_pyson":  "Eval('amount', 0) > 10000",
          "required_loa":     3,
          "max_age_seconds":  300,
          // El step-up es válido por 5 minutos antes de requerir re-autenticación.
          "acr_value":        "high_security"
        },
        {
          "trigger":          "system_config_change",
          "required_loa":     3,
          "max_age_seconds":  0,
          // max_age 0 = requiere autenticación fresca para cada operación.
          "acr_value":        "high_security"
        }
      ],

      "geospatial_control": {
        // Control de red/ubicación lógica. Sincronizado como User Attribute en KC.
        // SPI: SkbosGeoContextAuthenticator lee estos valores.
        "enabled": true,
        "allowed_locations": [
          {
            "type":         "office",
            "name":         "Sucursal La Paz — Av. Camacho 1234",
            "network_ranges":["10.0.1.0/24", "192.168.10.0/24"]
          },
          {
            "type":         "vpn",
            "name":         "VPN Corporativa SBOS",
            "network_ranges":["10.10.0.0/16"]
          },
          {
            "type":         "home_office",
            "name":         "Teletrabajo autorizado",
            "network_ranges":["*"],
            // * = cualquier red, pero requiere VPN activa
            "requires_vpn": true
          }
        ],
        "validation_rules": {
          "require_vpn":         false,
          // true = VPN obligatoria en TODAS las redes, incluso oficinas.
          "allow_roaming":       false,
          // false = solo redes pre-registradas.
          "require_corporate_network": false,
          // true = solo redes de la empresa.
          "geo_velocity_check":  true,
          // Detecta viaje imposible (> 1200 km/h entre logins).
          "max_velocity_kmh":    1200,
          "tolerance_km":        10
        }
      },

      "temporal_control": {
        // Control horario y de días. Sincronizado como User Attribute en KC.
        // SPI: SkbosRoleValidityAuthenticator + horas en Authentication Flow.
        "enabled": true,
        "schedule_type": "SPECIFIC_DAYS",
        // FULL_WEEK    → acceso todos los días
        // SPECIFIC_DAYS → solo días configurados
        // ALTERNATE_DAYS → alternados

        "timezone": "America/La_Paz",

        "allowed_days": [
          {
            "day": "MONDAY",
            "shifts": [
              {"start": "08:00", "end": "18:00"}
            ]
          },
          {
            "day": "TUESDAY",
            "shifts": [
              {"start": "08:00", "end": "18:00"}
            ]
          },
          {
            "day": "WEDNESDAY",
            "shifts": [
              {"start": "08:00", "end": "18:00"}
            ]
          },
          {
            "day": "THURSDAY",
            "shifts": [
              {"start": "08:00", "end": "18:00"}
            ]
          },
          {
            "day": "FRIDAY",
            "shifts": [
              {"start": "08:00", "end": "15:00"}
            ]
          }
        ],

        "exceptions": {
          "holidays":       "BLOCKED",
          // BLOCKED = no acceso, ALLOWED = acceso normal, REQUIRES_APPROVAL = con justificación
          "special_dates": [
            {
              "date":   "2026-02-01",
              "status": "BLOCKED",
              "reason": "Inventario Anual"
            }
          ],
          "emergency_override": {
            "allowed":         true,
            "requires_approval":true,
            "approver_roles":  ["DIRECTOR_VENTAS", "CISO"],
            "max_duration_hours": 4,
            "audit_logging":   "comprehensive"
          }
        },

        "session_management": {
          "max_session_duration_s":     28800,
          // 8 horas. Traducido a client.session.max.lifespan en KC.
          "inactivity_timeout_s":       900,
          // 15 minutos. Traducido a client.offline.session.idle.timeout en KC.
          "force_logout_at_end_shift":  true,
          // bAuth calcula fin de turno y KC expira la sesión.
          "concurrent_sessions_allowed":false,
          // false = máximo 1 sesión activa. maxSessionCount=1 en KC.
          "reauthentication_interval_s":14400
          // Re-autenticar cada 4 horas aunque la sesión esté activa.
        }
      }
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 5 — DOMINIO FÍSICO (Acceso Presencial)
    // Propósito: Controla acceso a espacios físicos, actuadores, hardware.
    // bAuth materializa en SAM-128 Q2 + device fichas banexus/bhnexus.
    // Estándar: ISO/IEC 27001 A.7, NIST SP 800-116, SIA OSDP v2.2.2
    // ═══════════════════════════════════════════════════════════════════

    "physical_access": {
      "enabled": true,

      "availableMethods": [
        "qr_dynamic",
        // QR HMAC-SHA256 generado por bAuth, TTL 30s
        "nfc_mifare_desfire",
        // NFC DESFire con AES-128, LoA 2
        "nfc_mifare_classic",
        // NFC Classic — solo legacy, LoA 1
        "rfid_125khz",
        // RFID Wiegand — baja seguridad, solo donde no hay alternativa
        "fingerprint_hash",
        // Hash PBKDF2-SHA256 del template, nunca raw biometric, LoA 3
        "face_hash",
        // Hash facial, LoA 3
        "smartcard_x509",
        // PKI en tarjeta, LoA 3-4
        "pin_pad"
        // PIN solo — nunca único factor, solo combinado
      ],

      "requiredMethods": {
        "standard_areas": [
          {"method": "nfc_mifare_desfire", "order": 1, "loa": 2}
        ],
        "restricted_areas": [
          {"method": "nfc_mifare_desfire", "order": 1, "loa": 2},
          {"method": "fingerprint_hash",   "order": 2, "loa": 3}
        ],
        "critical_areas": [
          {"method": "smartcard_x509",     "order": 1, "loa": 4},
          {"method": "fingerprint_hash",   "order": 2, "loa": 3}
        ]
      },

      "zones": [
        // Lista de zonas físicas accesibles para este rol.
        // Referencia al árbol jerárquico de 11 niveles en bhnexus.
        {
          "zone_id":        "PHY_ZONE_VENTAS",
          "name":           "Piso de Ventas — Planta Baja",
          "security_level": 2,
          // 1=público, 2=empleados, 3=restringido, 4=crítico
          "access_level":   "FULL",
          // FULL | READ_ONLY | TIMED | ESCORTED
          "schedule":       "business_hours",
          // business_hours | 24x7 | custom:{schedule_id}
          "access_points":  ["AP-PUERTA-01", "AP-PUERTA-02"]
        },
        {
          "zone_id":        "PHY_ZONE_ALMACEN",
          "name":           "Almacén General",
          "security_level": 2,
          "access_level":   "TIMED",
          "schedule":       "business_hours",
          "max_duration_minutes": 30
          // Para accesos TIMED: tiempo máximo por visita.
        },
        {
          "zone_id":        "PHY_ROOM_SERVIDOR",
          "name":           "Sala de Servidores",
          "security_level": 4,
          "access_level":   "DENIED"
          // DENIED explícito — este rol NO tiene acceso aunque esté en la misma zona padre.
        }
      ],

      "biometric_enrollment_policy": {
        // Define cómo se registran los datos biométricos de los usuarios con este rol.
        "mode":              "hybrid",
        // admin_only = solo admin registra
        // self_service = usuario registra sin supervisión
        // hybrid = usuario registra pero admin aprueba
        "risk_level":        "high",
        "liveness_required": true,
        "liveness_method":   "passive",
        // passive | active (desafío aleatorio) | combined
        "fallback_method":   "qr_dynamic",
        // Alternativa si el biométrico falla N veces consecutivas.
        "max_failed_attempts":3,
        "hash_algorithm":    "Argon2id",
        // Argon2id — ganador de PHC 2015, recomendado por OWASP ASVS 2.4.3 y NIST SP 800-63B Rev.4.
        // Parámetros: t=3 (time cost), m=64MB (memory), p=2 (parallelism) para LoA 2-3.
        // Reemplaza PBKDF2-SHA256. SHA1, MD5, bcrypt están deprecados para nuevos roles.
        "argon2_params": {
          "time_cost": 3,
          "memory_mb": 64,
          "parallelism": 2,
          "salt_length": 16,
          "hash_length": 32
        },
        "iterations":        "N/A_para_Argon2id",
        // OWASP 2023: mínimo 310.000 iteraciones para PBKDF2-SHA256 (solo referencia legacy)
        "fmr_threshold":     "1:10000"
        // False Match Rate aceptable (NIST SP 800-76-2).
        // 1:10.000 para LoA 2, 1:100.000 para LoA 3.
      },

      "physical_security_controls": {
        "two_person_rule":   false,
        // true = requiere dos personas simultáneamente (bóvedas, data centers)
        "mantrap_required":  false,
        // true = cámara esclusa entre dos puertas
        "anti_passback": {
          "enabled": true,
          "mode":    "hard",
          // hard = bloquea tailgating estrictamente
          // soft = permite pero alerta
          "reset_hours": 24
        }
      }
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 6 — ZONAS DE NEGOCIO (Dominio Lógico Abstracto)
    // Propósito: Define en qué zonas organizacionales puede operar este rol
    //            y con qué verbos. Las zonas se mapean a aplicaciones en
    //            zone_application_map.yaml — no al revés.
    // bAuth materializa en SAM-128 Q1 (LogicalDomainMask).
    // Estándar: OASIS XACML 3.0, NIST SP 800-162 (ABAC)
    // ═══════════════════════════════════════════════════════════════════

    "zones": {
      // Clave = nombre de zona de negocio (abstracto, no la app).
      // Verbos universales: READ | WRITE | DELETE | APPROVE | EXECUTE | CONFIGURE | AUDIT | EMIT
      // Las aplicaciones que implementan cada zona se resuelven en zone_application_map.yaml.

      "zone_logical/ventas": {
        "verbs":            ["READ", "WRITE", "APPROVE", "EXECUTE"],
        "scope":            "REGIONAL",
        // GLOBAL | REGIONAL | LOCAL | PERSONAL
        // REGIONAL = solo datos de su territorio (Record Rule automática en Tryton)
        "restrictions": {
          "max_record_limit": 1000,
          // Número máximo de registros retornados por consulta
          "data_classification": ["PUBLIC", "INTERNAL", "CONFIDENTIAL"]
          // Niveles de clasificación de datos accesibles en esta zona
        },
        "applications": [
          // Hint de qué apps implementan esta zona.
          // El evaluador lógico resuelve via zone_application_map.yaml.
          {"app": "tryton",   "modules": ["sale", "sale.opportunity", "party"]},
          {"app": "saleor"},
          {"app": "espocrm"}
        ]
      },

      "zone_logical/facturacion": {
        "verbs":            ["READ", "WRITE", "EMIT"],
        "scope":            "REGIONAL",
        "restrictions": {
          "data_classification": ["INTERNAL", "CONFIDENTIAL"]
        },
        "applications": [
          {"app": "tryton",   "modules": ["account_invoice", "account"]},
          {"app": "superset", "dashboards": ["facturacion_regional"]},
          {"app": "paperless","tags": ["factura", "nota_credito"]}
        ]
      },

      "zone_logical/reportes": {
        "verbs":            ["READ", "EXECUTE"],
        "scope":            "REGIONAL",
        "applications": [
          {"app": "superset"},
          {"app": "tryton",   "modules": ["account_statement"]}
        ]
      },

      "zone_logical/clientes": {
        "verbs":            ["READ", "WRITE"],
        "scope":            "REGIONAL",
        "restrictions": {
          "pii_access":          true,
          // Este rol accede a PII — logging extra + enmascaramiento parcial
          "masking_policy":      "lastFourVisible",
          "data_classification": ["CONFIDENTIAL"]
        },
        "applications": [
          {"app": "espocrm"},
          {"app": "tryton",   "modules": ["party"]}
        ]
      },

      "zone_financial/ventas": {
        "verbs":            ["CREATE", "APPROVE"],
        "scope":            "REGIONAL",
        "limit_tier":       2,
        // Tier 0=sin ops, 1=hasta 1k, 2=hasta 10k, 3=hasta 50k, 4=hasta 200k, 5=sin límite
        "sod_cannot_also":  "zone_financial/ventas:AUDIT",
        // SoD: quien crea/aprueba ventas no puede auditarlas
        "requires_dual_approval_above": 10000,
        // Monto en moneda local (currency del tenant) que requiere 2 aprobadores
        "currency":         "BOB"
      }
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 7 — PRIVILEGIOS TRYTON (5 Capas Nativas)
    // Propósito: Definición explícita de cada capa de enforcement en Tryton.
    // bAuth genera estos objetos automáticamente en Tryton al sincronizar.
    // Estándar: Tryton ir.model.access, ir.rule, ir.model.button, ir.action.groups
    // ═══════════════════════════════════════════════════════════════════

    "tryton_privileges": {

      "model_access": [
        // CAPA 1 — Permisos CRUD por modelo de datos.
        // Si read=false → el usuario no ve NINGÚN dato de ese modelo.
        {"model":"sale.order",         "read":true,  "write":true,  "create":true,  "delete":false},
        {"model":"sale.opportunity",   "read":true,  "write":true,  "create":true,  "delete":false},
        {"model":"sale.line",          "read":true,  "write":true,  "create":true,  "delete":false},
        {"model":"party.party",        "read":true,  "write":true,  "create":true,  "delete":false},
        {"model":"party.address",      "read":true,  "write":true,  "create":true,  "delete":false},
        {"model":"account.invoice",    "read":true,  "write":false, "create":false, "delete":false},
        {"model":"account.invoice.line","read":true, "write":false, "create":false, "delete":false},
        {"model":"account.payment",    "read":true,  "write":true,  "create":true,  "delete":false},
        {"model":"product.product",    "read":true,  "write":false, "create":false, "delete":false},
        {"model":"product.category",   "read":true,  "write":false, "create":false, "delete":false},
        {"model":"stock.shipment.out", "read":true,  "write":false, "create":false, "delete":false},
        {"model":"res.user",           "read":false, "write":false, "create":false, "delete":false},
        // Ningún rol puede leer la tabla de usuarios — aislamiento de privacidad
        {"model":"ir.model",           "read":false, "write":false, "create":false, "delete":false}
      ],

      "visible_actions": [
        // CAPA 2 — Menús y acciones visibles en la UI de Tryton.
        // Menús no listados aquí son INVISIBLES para el usuario.
        "menu_sale_orders",
        "menu_sale_opportunities",
        "menu_sale_products",
        "menu_sale_reports_regional",
        "menu_party_customers",
        "menu_party_addresses",
        "menu_account_invoice_view",
        "menu_account_payment_view",
        "menu_dashboard_ventas",
        "menu_stock_shipment_out_view"
      ],

      "field_restrictions": [
        // CAPA 3 — Acceso a campos individuales.
        // Campos con read:false son eliminados de las vistas automáticamente.
        {"model":"account.invoice",    "field":"margin",       "read":false, "write":false},
        {"model":"account.invoice",    "field":"cost_price",   "read":false, "write":false},
        {"model":"sale.order",         "field":"cost_price",   "read":false, "write":false},
        {"model":"sale.line",          "field":"margin",       "read":false, "write":false},
        {"model":"party.party",        "field":"credit_limit", "read":true,  "write":false},
        // Solo puede ver el límite de crédito, no modificarlo
        {"model":"product.product",    "field":"cost_price",   "read":false, "write":false}
      ],

      "button_rules": [
        // CAPA 4 — Control de botones y aprobaciones con PYSON.
        // El campo sod_cannot_also define restricciones de SoD.
        {
          "model":           "sale.order",
          "button":          "confirm",
          "users_required":  1,
          "condition_pyson": "Eval('amount_total', 0) <= 10000",
          "sod_cannot_also": null,
          "step_up_loa":     null,
          "description":     "Confirmar venta hasta 10.000 BOB — sin restricción adicional"
        },
        {
          "model":           "sale.order",
          "button":          "confirm",
          "users_required":  2,
          "condition_pyson": "And(Eval('amount_total', 0) > 10000, Eval('amount_total', 0) <= 50000)",
          "sod_cannot_also": null,
          "step_up_loa":     3,
          "description":     "Confirmar venta 10.001–50.000 BOB — requiere 2 aprobadores + WebAuthn"
        },
        {
          "model":           "sale.order",
          "button":          "cancel",
          "users_required":  1,
          "condition_pyson": "Eval('state', '') == 'draft'",
          "sod_cannot_also": null,
          "step_up_loa":     null
        },
        {
          "model":           "account.payment",
          "button":          "approve",
          "users_required":  2,
          "condition_pyson": "Eval('amount', 0) > 5000",
          "sod_cannot_also": "account.payment:create",
          // SoD: quien creó el pago no puede aprobarlo
          "step_up_loa":     3,
          "description":     "Aprobar pago > 5.000 BOB — SoD activo + WebAuthn"
        }
      ],

      "record_rules": [
        // CAPA 5 — Reglas de registros (filtros SQL automáticos).
        // Tryton agrega estos filtros a CADA consulta SQL del usuario.
        {
          "model":       "sale.order",
          "domain_pyson":"[('shop.region', '=', Eval('context', {}).get('user_region', ''))]",
          "description": "Solo pedidos de la región norte asignada al usuario"
        },
        {
          "model":       "sale.opportunity",
          "domain_pyson":"[('responsible.id', '=', Eval('user.id', 0))]",
          "perm_write_exception": true,
          // write_exception = puede escribir en oportunidades ajenas si es manager
          "description": "Solo oportunidades propias o asignadas al equipo regional"
        },
        {
          "model":       "party.party",
          "domain_pyson":"[('category', 'in', ['CUSTOMER', 'PROSPECT', 'SUPPLIER'])]",
          "description": "Solo clientes, prospectos y proveedores — nunca internos ni empleados"
        }
      ]
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 8 — DOMINIO FINANCIERO (Transacciones y SoD)
    // Propósito: Regula operaciones económicas, límites y aprobaciones.
    // bAuth materializa en SAM-128 Q3 (FinancialDomainMask).
    // Estándar: PCI-DSS v4.0, ISO 27001 A.5.3, NIST SP 800-53 AC-5, ISACA COBIT 2019
    // ═══════════════════════════════════════════════════════════════════

    "financial_transactions": {
      "enabled": true,

      "availableMethods": [
        // Métodos de autenticación adicionales requeridos para operaciones financieras.
        "smart_card_pin",
        "mobile_token",
        "biometric_validation",
        "digital_signature",
        "hardware_security_token"
      ],

      "requiredMethods": {
        "standard_transactions": [
          {"method": "smart_card_pin", "order": 1},
          {"method": "mobile_token",   "order": 2}
        ],
        // Transacciones estándar (hasta single_transaction_limit).

        "high_value_transactions": [
          {"method": "smart_card_pin",      "order": 1},
          {"method": "mobile_token",         "order": 2},
          {"method": "biometric_validation", "order": 3}
        ]
        // Transacciones de alto valor (> requires_dual_approval_above).
      },

      "transaction_schedule": {
        // Ventanas de tiempo durante las cuales se permiten transacciones financieras.
        "type": "SCHEDULED",
        // CONTINUOUS = sin restricción horaria
        // SCHEDULED  = solo en períodos definidos
        "schedules": [
          {
            "name": "Pagos a Proveedores — Quincenal",
            "periods": [
              {
                "days_of_month": [13, 14, 15],
                "hours": {"start": "09:00", "end": "16:00"},
                "timezone": "America/La_Paz"
              },
              {
                "days_of_month": [28, 29, 30, 31],
                "hours": {"start": "09:00", "end": "16:00"},
                "timezone": "America/La_Paz"
              }
            ]
          }
        ],
        "emergency_override": {
          "allowed":         true,
          "requires_approval":true,
          "approver_roles":  ["FINANCE_DIRECTOR", "CEO"],
          "max_duration_hours": 2,
          "audit_logging":   "critical"
        }
      },

      "transaction_limits": {
        "currency":               "BOB",
        "single_transaction_limit": 10000,
        // Una sola transacción. Si > límite: requiere aprobación adicional.
        "daily_limit":            50000,
        // Suma de todas las transacciones del día.
        "monthly_limit":          200000,
        // Suma mensual.
        "per_period_limit":       100000,
        // Por período de nómina/quincenal.
        "requires_dual_approval_above": 10000
        // > N BOB requiere 2 aprobadores distintos.
      },

      "sod_rules": [
        // Segregación de Funciones — evaluada por Conflict Matrix en bAuth.
        // Estas reglas se aplican ANTES de guardar asignaciones de rol.
        {
          "action":        "zone_financial/ventas:CREATE",
          "cannot_also":   "zone_financial/ventas:APPROVE",
          "description":   "Quien crea ventas no puede aprobar sus propias ventas",
          "severity":      "critical"
        },
        {
          "action":        "zone_financial/pagos:CREATE",
          "cannot_also":   "zone_financial/pagos:APPROVE",
          "description":   "Separación creador/aprobador de pagos",
          "severity":      "critical"
        }
      ],

      "geospatial_control": {
        // Restricción geográfica específica para operaciones financieras.
        "allowed_locations": [
          {
            "type":          "office",
            "name":          "Oficina Central Finanzas — La Paz",
            "network_ranges":["10.0.1.0/24"]
          }
        ],
        "validation_rules": {
          "require_secure_network":       true,
          "allow_remote":                 false,
          "require_location_verification":true,
          "require_vpn":                  false
        }
      }
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 9 — SAM-128 + BITMASK 64-bit (Sovereign Authority Matrix)
    // Propósito: Representación binaria calculada por PrivilegeEngine.
    // Solo lectura — bAuth lo calcula automáticamente desde los bloques anteriores.
    //
    // ARQUITECTURA DE DOBLE CAPA (bAuth v2.0):
    // - BitMask 64-bit (catálogo de roles): capa 1 [31:0] sistema, capa 2 [63:32] negocio.
    //   Usada para herencia de privilegios via DAG (OR bitwise).
    //   Documentada en: BAUTH-CATALOGO-ROLES-EMPRESARIALES.md v2.0 §6.
    // - SAM-128 (éste bloque): matriz de autoridad soberana de 128 bits.
    //   Extiende el BitMask con dominios físico, financiero, y de gobernanza.
    //
    // Estándar: SBOS-BITMASK-ANALISIS-SAM128-Y-PLAN-CORREGIDO v1.0
    // ═══════════════════════════════════════════════════════════════════

    "sam128": {
      "_readonly": true,
      "_description": "Calculado por PrivilegeEngine. No editar manualmente.",
      "bitmask_64_ref": {
        "_description": "El BitMask 64-bit del catálogo alimenta los primeros 64 bits del SAM-128.",
        "layer1_system_mask": "bits_0_31_privilegios_sistema",
        "layer2_business_mask": "bits_32_63_privilegios_negocio",
        "effective_mask": "mask_own_OR_mask_efectiva_de_todos_los_junior",
        "inheritance": "DAG_NIST_RBAC_§4.2"
      },
      "physical_domain_mask_hex": "0x000000000003E627",
      // SAM-128 Q1+Q2 (bits 0-63): dominio físico + lógico básico
      "logical_domain_mask_hex":  "0x0000010900030052",
      // SAM-128 Q1 extendido: zonas de negocio × verbos
      "financial_domain_mask_hex":"0x0000020900010000",
      // SAM-128 Q3 (bits 64-95): dominio financiero
      "governance_mask_hex":      "0x0000021200010052",
      // SAM-128 Q4 (bits 96-127): soberanía, LoA, auditoría
      "computed_at":              "2026-06-20T10:35:00Z",
      "computed_by":              "bAuth.PrivilegeEngine.v2.0"
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 10 — DELEGACIÓN
    // Propósito: Controla cómo este rol puede delegar permisos temporalmente.
    // Implementa DSD (Dynamic Separation of Duties) según ANSI/INCITS 359-2004 §4.2.
    // ═══════════════════════════════════════════════════════════════════

    "delegation_config": {
      "can_delegate":        true,
      "max_duration_days":   21,
      // Una delegación no puede durar más de 21 días.
      "delegable_to_roles":  ["SUP-NORTE-001", "GER-VENTAS-SUR"],
      // Solo puede delegar a estos roles específicos.
      "non_delegable_permissions": [
        // Permisos que NUNCA pueden ser delegados, independientemente.
        "zone_logical/reportes:CONFIGURE",
        "zone_financial/ventas:APPROVE",
        "GOV_ADMIN_USERS"
      ],
      "requires_approval":   true,
      "approver_roles":      ["DIRECTOR_VENTAS"],
      "max_concurrent_delegations": 1,
      // Solo una delegación activa a la vez.
      "auto_revoke_on_expiry": true,
      // bAuth revoca automáticamente al vencer valid_until.
      "notification_channels":["email", "rocket_chat"]
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 11 — GESTIÓN DE GRUPOS Y JERARQUÍAS
    // Propósito: Define herencia, grupos funcionales y reglas de composición.
    // ═══════════════════════════════════════════════════════════════════

    "group_management": {
      "role_hierarchy": {
        "level":        2,
        "parent_role":  "VEN-BASE-001",
        "child_roles":  ["SUP-NORTE-001", "VEN-VEN-NORTE-001"],
        "inheritance_rules": {
          "inherit_permissions": true,
          "bits_removed_from_parent": [
            "PERM_CONFIG",
            // Este rol hereda de VEN-BASE-001 pero NO puede configurar el sistema
            "GOV_ADMIN_USERS"
          ],
          // Implementación: SAM = parent_mask &^ bits_removed (AND NOT)
          "permission_modifications": {
            "FIN_LIMIT_TIER": {
              "parent_value": 3,
              // Tier 3 en el padre (hasta 50k)
              "inherited_value": 2
              // Este rol solo tiene Tier 2 (hasta 10k)
            }
          }
        }
      },

      "role_groups": [
        {
          "group_id":         "VENTAS_TEAM",
          "group_type":       "FUNCTIONAL",
          "members":          ["RGV-001", "SUP-NORTE-001", "VEN-VEN-NORTE-001"],
          "shared_permissions":["zone_logical/ventas:READ", "zone_logical/clientes:READ"],
          "group_policies": {
            "minimum_active_members": 1,
            "quorum_requirements": {
              "high_value_sales":  2,
              // Para ventas > 10k BOB se necesitan 2 miembros del grupo activos
              "policy_changes":    3
            }
          }
        }
      ]
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 12 — GESTIÓN DE CONFLICTOS (SoD y Conflicto de Intereses)
    // Propósito: Prevent fraud mediante separación formal de funciones.
    // Estándar: ISACA COBIT 2019, ISO 27001 A.5.3, NIST SP 800-53 AC-5
    // ═══════════════════════════════════════════════════════════════════

    "conflict_management": {
      "segregation_of_duties": {
        "incompatible_roles": [
          // Roles que NO pueden coexistir en el mismo usuario con este rol.
          {
            "incompatible_with": "FIN-AUDIT-001",
            "description":       "Gerente de ventas no puede ser auditor financiero",
            "severity":          "critical",
            "mitigation":        "DENY"
            // DENY = bloquea la asignación
            // APPROVE = requiere aprobación especial
          }
        ],
        "incompatible_functions": [
          {
            "function_a": "zone_financial/ventas:CREATE",
            "function_b": "zone_financial/ventas:AUDIT",
            "description":"Quien crea transacciones no puede auditarlas",
            "severity":   "critical",
            "mitigation": "DENY"
          }
        ],
        "conflict_validation": {
          "check_frequency": "REAL_TIME",
          // bAuth valida en cada solicitud de acceso y en cada cambio de rol
          "validation_scope":["DIRECT_CONFLICTS", "INHERITED_CONFLICTS", "DELEGATION_CONFLICTS"]
        }
      },

      "interest_conflicts": {
        "restricted_entities": [
          {
            "type": "VENDORS",
            "validation_rules": {
              "check_ownership":      true,
              "check_relationship":   true,
              "relationship_degrees": 2
              // Familiares hasta 2do grado no pueden ser proveedores auditados por este rol
            }
          }
        ],
        "declaration_requirements": {
          "frequency":                "ANNUAL",
          "requires_update_on_change":true,
          "verification_method":      "COMPLIANCE_REVIEW",
          "documentation":            "mandatory"
        }
      }
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 13 — CUMPLIMIENTO Y AUDITORÍA
    // Propósito: Garantizar trazabilidad y cumplimiento normativo.
    // Estándar: ISO 27001 A.8.15, RGPD Art.30, SOX §404, PCI-DSS Req.10
    // ═══════════════════════════════════════════════════════════════════

    "compliance_audit": {
      "review_frequency":  "QUARTERLY",
      // MONTHLY | QUARTERLY | SEMIANNUAL | ANNUAL
      "last_review_date":  "2026-01-01T00:00:00Z",
      "next_review_date":  "2026-07-01T00:00:00Z",
      "review_scope": [
        "ACCESS_PATTERNS",
        "PERMISSION_USAGE",
        "DELEGATION_HISTORY",
        "CONFLICT_VIOLATIONS",
        "FINANCIAL_TRANSACTIONS"
      ],
      "reviewers":         ["DIRECTOR_VENTAS", "COMPLIANCE_OFFICER", "INTERNAL_AUDIT"],

      "regulatory_frameworks": {
        "pci_dss": {
          "applicable":    true,
          "requirements":  ["Req.7", "Req.8", "Req.10"],
          "review_evidence":["access_logs", "sod_matrix", "mfa_enforcement"]
        },
        "gdpr": {
          "applicable":    true,
          "pii_access":    true,
          "legal_basis":   "legitimate_interest",
          "data_minimization": true,
          "retention_days":365
        }
      },

      "access_review_policy": {
        "auto_revoke_on_review_failure": false,
        // Si el revisado no responde a la revisión en SLA → auto-revocar
        "sla_days":       14,
        "escalation":     ["CISO", "HR_DIRECTOR"]
      },

      "change_tracking": {
        "tracked_elements": [
          "PERMISSIONS", "AUTHENTICATION_METHODS", "TEMPORAL_ACCESS",
          "DELEGATIONS", "FINANCIAL_LIMITS", "SOD_RULES"
        ],
        "retention_years": 7
        // ISO 27001 + SOX: mínimo 7 años para registros financieros
      }
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 14 — ESTADO DE SINCRONIZACIÓN
    // Propósito: Rastrear sincronización con KC y Tryton.
    // Gestionado por bAuth — solo lectura para administradores.
    // ═══════════════════════════════════════════════════════════════════

    "sync_state": {
      "_readonly":     true,
      "_description":  "Gestionado exclusivamente por bAuth.PrivilegeEngine. No editar.",
      "sync_status":   "SYNCED",
      // PENDING | SYNCING | SYNCED | ERROR | ERROR_TRYTON_PENDING | DRIFT
      "last_sync_at":  "2026-03-01T10:35:00Z",
      "sync_targets": {
        "keycloak": {
          "status":          "SYNCED",
          "composite_role":  "RGV_001",
          "group_path":      "/Empresa-ACME/Ventas/Norte",
          "auth_flow":       "RGV_001_browser_flow",
          "realm_roles":     ["SALES_VIEW", "SALES_WRITE", "SALES_APPROVE_10K", "REPORTS_REGIONAL"],
          "last_synced_at":  "2026-03-01T10:35:00Z"
        },
        "tryton": {
          "status":          "SYNCED",
          "group_id":        847,
          "group_name":      "RGV_001",
          "last_synced_at":  "2026-03-01T10:35:00Z"
        }
      },
      "drift_detected":  false,
      "drift_details":   null
    }

  }
}
```

### 19.2 Las tablas de mapping de materialización `[pre-ADR-010]`

> Materialización de época del contrato v6.0 (los destinos externos fueron eliminados por
> ADR-010 — bAuth cubre estos flujos nativamente). Se trasladan porque B7 y B14 las
> referencian y documentan el CONCEPTO de traducción declarativa (contrato → objetos del
> motor de ejecución), que permanece vigente con destino nativo.

#### Tabla de mapping ROLTEMPLATE → motor de identidad externo `[pre-ADR-010]`

| Campo RolTemplate | Objeto KC creado | Tipo de sync |
|---|---|---|
| `logical_access.requiredMethods` | Authentication Flow `{id}_browser_flow` | CREATE + UPDATE |
| `logical_access.geospatial_control.allowed_locations` | User Attribute `allowed_networks` | UPDATE user |
| `logical_access.temporal_control.allowed_days` | User Attributes `allowed_days`, `shift_start`, `shift_end` | UPDATE user |
| `validity_period.end_date` | User Attribute `role_valid_until` | UPDATE user |
| `logical_access.session_management.max_session_duration_s` | `client.session.max.lifespan` | UPDATE client |
| `logical_access.session_management.concurrent_sessions_allowed` | `maxSessionCount: 1/N` | UPDATE realm |
| `id` | Composite Role name = `{id}` | CREATE |
| `zones.*.verbs` | Realm Roles atómicos | CREATE/DELETE |
| `sam128.governance_mask_hex` | User Attribute `bos_sam128_governance` | UPDATE user |

---

#### Tabla de mapping ROLTEMPLATE → ERP `[pre-ADR-010]`

| Campo RolTemplate | Objeto Tryton creado | Capa |
|---|---|---|
| `id` | `res.group` con name = `{id}` | Base |
| `tryton_privileges.model_access` | `ir.model.access` por modelo | Capa 1 |
| `tryton_privileges.visible_actions` | `ir.action.groups` | Capa 2 |
| `tryton_privileges.field_restrictions` | `ir.model.field.access` | Capa 3 |
| `tryton_privileges.button_rules` | `ir.model.button` + Button Rule | Capa 4 |
| `tryton_privileges.record_rules` | `ir.rule.group` | Capa 5 |


### 19.3 Las estructuras propuestas de los bloques nuevos (PR-2 del plan de reparación — pendientes de HITL)

**B15 `geospatial_policy` (D6):**

```json
"geospatial_policy": {
  "allowed_locations": [...],          // ÚNICA fuente de verdad
  "validation_rules": {...},
  "financial_override": {              // si null → usa las mismas reglas base
    "require_secure_network": true,
    "allow_remote": false
  },
  "gps_attestation": {                 // para métodos con GPS (am22, am4, am6)
    "required": false,
    "max_accuracy_meters": 100,
    "provider": "FIDO2_GPS_ATTESTATION"
  }
}
```

**B16 `network_access` (D7):**

```json
"network_access": {
  "enabled": true,
  "zero_trust_mode": true,            // NIST SP 800-207: never trust always verify
  "device_compliance": {
    "required": true,
    "check_provider": "kong_opa",     // Kong + OPA como PEP
    "posture_requirements": ["managed", "patched", "encrypted"]
  },
  "allowed_ranges": [                 // extrae de geospatial_control actual
    {"type": "office",   "cidr": "10.0.1.0/24"},
    {"type": "vpn",      "cidr": "10.10.0.0/16"},
    {"type": "any",      "requires_vpn": true}
  ],
  "mtls_required": false,             // si true → client cert en cada request
  "api_gateway_rules": {
    "rate_limit_rpm": 1000,
    "allowed_origins": ["*"],
    "kong_plugins": ["rate-limiting", "ip-restriction", "bot-detection"]
  },
  "network_segmentation": {
    "vlan_id": null,
    "micro_segmentation": false
  }
}
```

**B17 `adaptive_context` (D8):**

```json
"adaptive_context": {
  "risk_engine": {
    "provider": "bauth_internal",
    "evaluation_mode": "continuous",   // no solo al login
    "revoke_on_anomaly": true,         // revoca token si riesgo aumenta
    "assessment_interval_s": 300
  },
  "context_signals": {
    "device_posture": true,            // ¿dispositivo gestionado y actualizado?
    "user_behavior": true,             // baseline de horarios, IPs, velocidad de tecleo
    "threat_intel": false,             // feed externo de IPs maliciosas
    "impossible_travel": true,         // ya en geospatial_control (cross-ref D6)
    "new_device": true,                // primer acceso desde este dispositivo
    "time_of_day": true                // cross-ref con D4 temporal_control
  },
  "adaptive_policies": [
    {
      "condition": "risk_score > 0.7",
      "action":    "step_up",
      "required_loa": 3
    },
    {
      "condition": "risk_score > 0.9",
      "action":    "block",
      "notify_channels": ["email", "rocket_chat"]
    }
  ],
  "emergency_access": {
    "allowed": true,
    "bypass_conditions": ["verified_emergency", "dual_approval"],
    "max_duration_hours": 4,
    "audit": "critical"
  }
}
```

**B18 `credential_lifecycle` (D9):**

```json
"credential_lifecycle": {
  "enrollment_policy": {
    "verification_level": "IAL2",      // IAL1=self-asserted, IAL2=verificado, IAL3=presencial
    "requires_supervisor_approval": true,
    "enrollment_channels": ["admin_portal", "self_service"],
    "binding_type": "post_enrollment"  // NIST 800-63B-4 §6.1.2
  },
  "rotation_policy": {
    "password": {
      "mandatory_rotation": false,     // NIST 800-63B-4 eliminó rotación forzada
      "trigger_on_breach": true,       // sí rotar si aparece en lista de brechas
      "min_age_days": 1
    },
    "totp_seed": { "rotation_on_device_change": true },
    "x509_cert": { "max_age_days": 365, "auto_renew": true }
  },
  "revocation_policy": {
    "immediate_on_termination": true,  // al salir del rol → revocar en < 30s
    "suspension_before_revoke": true,  // suspender antes de revocar (permite reintegro)
    "suspension_grace_days": 7,
    "channels": ["keycloak", "vault", "kong"]
  },
  "privilege_creep_detection": {
    "enabled": true,
    "review_interval_days": 90,
    "auto_flag_threshold": 0.3         // si 30% de permisos no usados → alert
  },
  "recovery_policy": {
    "channels": ["email_recuperacion", "supervisor_approval"],
    "identity_verification_required": "IAL1",
    "max_recovery_attempts": 3
  }
}
```

**B19 `blockchain_access` (D12):**

```json
"blockchain_access": {
  "enabled": false,                    // mayoría de roles no necesita
  "network": {
    "chain": "besu_qbft",
    "chain_id": 1337,
    "node_endpoint": "internal"        // via bnexa, nunca directo
  },
  "signing_config": {
    "algorithm": "ECDSA_secp256k1",    // para Besu EVM
    "key_managed_by": "vault",         // Vault PKI Engine
    "key_path": "besu/keys/{role_id}"
  },
  "ley164_compliance": {
    "required": false,                 // true = firma con validez jurídica Bolivia
    "adsib_cert_required": false,      // certificado ADSIB/SIN
    "rnd_102100000011": false          // SIN facturación electrónica
  },
  "smart_contract_permissions": [
    {
      "contract": "AuditLog",
      "functions": ["appendEntry"],    // append-only para este rol
      "read_only": false
    }
  ],
  "on_chain_audit": {
    "enabled": false,
    "event_types": ["high_value_approval", "role_change"]
  },
  "wallet_policy": {
    "rotation_on_compromise": true,
    "max_transaction_value_wei": null  // null = sin límite de token value
  }
}
```

---

## 19.bis Estado de materialización en código (verificado 2026-07-11)

El contrato NO es solo diseño — su materialización está verificada en el esquema:

| Pieza | Evidencia en código | Estado |
|---|---|---|
| Tabla `idn_role_template` | `DDLs/migrations/sbos_00__esquema_base.sql:2449` (`CREATE TABLE`) | ✅ existe |
| Catálogo `idn_role_type` (G-B01-03) | seed `bauth_47a__idn_role_type.sql` (10 tipos NIST) | ✅ sembrado |
| ENUM `role_status_type` (G-B01-05) | seed `bauth_47b__role_status_enum.sql` | ✅ |
| Los 548 roles (G-B01-03/04) | seed `bauth_48__idn_role_template.sql` — **548 `uuidv7()`** (grep confirmado) | ✅ sembrado |
| Closure de herencia (G-B01-04) | seed `bauth_62__idn_role_closure.sql` (1673 relaciones) | ✅ |
| Validador | `roltemplate_validator.rs` (279 líneas — A.23) | ✅ real |

**Veredicto:** los bloques B1-B2 del contrato están **materializados y verificados en VPS** (las
7 resoluciones G-B01/B02). Lo que falta es la materialización de B15-B20 (los dominios nuevos,
§17) y el cómputo de B9/SAM-128 (A.17-C2). El contrato es real donde está resuelto, diseño donde
está en reparación — sin ambigüedad.

## 20. Mapa anexo → manuales

| Sección de este anexo | Respalda a |
|---|---|
| §B1 (id/versión/status/auditoría) | 1.09 §2.5, §6, §11 · 1.13 §5, §9.2 |
| §B2 (vigencia) | 1.09 §10 (ciclo de vida) |
| §B3 (aprobación) | 1.13 §8.2/§9.3 (`ver_proposal` = este workflow) |
| §B4 (dominio lógico) | 2.01 Autenticación · 2.02 Métodos · 2.03 Tokens (sesiones) |
| §B5 (físico) | 1.01 Dominios (D2) |
| §B6 (zonas) | 2.05 Políticas · 1.02 Verbos · 2.10 (clasificación/PII) |
| §B7 (5 capas) | 1.10 Aplicaciones |
| §B8 (financiero) | 1.01 (D3) · 2.04 Firma (umbral legal) |
| §B9 (BitMask) | 1.04 BitMask |
| §B10-§B12 (DSD/RBAC1/SSD) | 1.09 §9 (herencia) · 7.01 IGA (SoD/certificación) |
| §B13 (cumplimiento) | 5.01 Auditoría · 7.03 Normas |
| §B14 (sync) | 1.09 §7 (campo template) |
| §17 (estructura completa D00–D13, bloques nuevos, defases) | 1.01 Dominios (taxonomía y pipeline) · 3.01 Riesgo (D8) · 5.02 Blockchain (D12) · 2.04 Firma (D13) · 2.09 Red (D7) |

---

## 21. Referencias e historial

**Del proyecto:** `SBOS-ROLTEMPLATE-v6_0` (SSOT del contrato + plan PR-1..PR-6) · `BAUTH-ORIGEN-NORMATIVO-ROLTEMPLATE-2026-07-08` (tracking G-B*) · MANUAL-DOMINIOS (1.01 §4-§5: taxonomía D00–D13 y pipeline) · `BAUTH-CATALOGO-ROLES-EMPRESARIALES` v2.0 · `BAUTH-CADENAS-JERARQUIA` v1.1 · `SBOS-BITMASK-ANALISIS-SAM128-Y-PLAN-CORREGIDO` · ADR-009 · ADR-010.

**Fuentes primarias (verificación 2026-07-11):** [INCITS 359 RBAC](https://blog.ansi.org/ansi/role-based-access-control-rbac-incits-359/) · [NIST RBAC Project](https://csrc.nist.gov/projects/role-based-access-control) · [NIST SP 800-63B](https://pages.nist.gov/800-63-4/sp800-63b.html) · [AAL](https://pages.nist.gov/800-63-3-Implementation-Resources/63B/AAL/) · [Session Management](https://pages.nist.gov/800-63-3-Implementation-Resources/63B/Session/) · [RFC 9470](https://datatracker.ietf.org/doc/html/rfc9470) · [RFC 8693](https://datatracker.ietf.org/doc/html/rfc8693) · [NIST SP 800-207](https://csrc.nist.gov/pubs/sp/800/207/final) · [NIST SP 800-162](https://csrc.nist.gov/pubs/sp/800/162/upd2/final) · [PCI DSS](https://www.pcisecuritystandards.org/document_library/) · [SIN Bolivia](https://www.impuestos.gob.bo/) · [ADSIB](https://desarrollo.adsib.gob.bo/paginas-web/firma-digital/)

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.1.0 | 2026-07-11 | **Añadida verificación de código real** (§19.bis: tabla idn_role_template (sbos_00:2449) + seeds 47a/47b/48(548)/62 materializados; B15-B20 y SAM-128 pendientes). |
| 1.0.0 | 2026-07-11 | Anexo inicial (solicitud del humano: documentación respaldatoria estructurada, no copias). Reorganiza el contrato RolTemplate v6.0 completo en 14 secciones referenciables (§B1–§B14, tabla de partes por bloque con campo·significado·norma), integra el origen normativo campo a campo (códigos G-B* con las 7 resoluciones aplicadas y su estado real en VPS), la verificación contra fuentes primarias (los 4 componentes RBAC como bloques; AAL/step-up/sesiones de 800-63B; PRMS de INCITS; SSD en asignación), el plan B15–B21, las validaciones del contrato, las marcas `[pre-ADR-010]` para la materialización de época (sin destruir contenido), y el mapa sección→manual que respalda. |
| 1.1.0 | 2026-07-11 | **§17 reescrita: la estructura COMPLETA por dominios** (corrección del humano: todos los dominios deben estar representados). Incorpora: la matriz de cobertura de los 14 planos D00–D13 (+D99) contra la estructura del rol — consolidando PR-1 del SSOT con la tabla maestra y el pipeline de MANUAL-DOMINIOS 1.01 §4-§5 (D4/D6 sin átomos propios encadenados a D1; D8/D9 pre-BitMask); la especificación de estructura de los 5 bloques nuevos B15–B19 (geoespacial unificado, red/ZTA, contexto adaptativo con los 4 event types de OpenID CAEP 1.0 verificados en la spec final, ciclo de vida de credenciales 800-63B-4 §6, blockchain) y de los 3 enriquecimientos (D0 en B1, D4 cross-refs, D5 en B5 con ISO 30107-3); **tres defases detectados y documentados para HITL**: (1) D13 Firma Digital Externa ausente del plan del SSOT — con recomendación de separar de D12; (2) numeración doble B15–B21 (bloques del contrato ≠ secciones de tracking del doc de gaps) — canónica declarada: la del SSOT; (3) B14 sync_targets pre-ADR-010; el árbol completo y la secuencia de 10 pasos HITL. |
| 2.0.0 | 2026-07-11 | **MAJOR — cambio de estatus: el anexo pasa a FUENTE AUTOSUFICIENTE** (decisión del humano: los anexos son la nueva documentación; la legacy deja de consultarse). Nueva §19 «Traslado fiel»: la estructura JSONB COMPLETA del contrato v6.0 (los 14 bloques íntegros, extracción literal — no transcripción), las tablas de mapping de materialización `[pre-ADR-010]` y las 5 estructuras JSON propuestas de los bloques nuevos B15–B19 (PR-2). §1 actualizado al nuevo estatus (con la excepción operativa: el doc de gaps sigue siendo el tracking activo). Secciones renumeradas: mapa→§20, referencias→§21. |
| 2.1.0 | 2026-07-11 | **Verificación de completitud RESUELTA + materialización nativa** (corrección del humano: la solución autosuficiente ya está documentada en los manuales; la completitud se resuelve con normas+estándares+industria). §17.4 pasa de "defases para HITL" a **RESOLUCIONES**: (1) D13 → especificado el **nuevo bloque `B20 legal_signature_policy`** del rol (operaciones que exigen firma jurídica, motor requerido INTERNAL/EXTERNAL_ADSIB de 2.04, requisitos de certificado ADSIB, evidencia — fundamento Ley 164/eIDAS: el certificado es de la persona → el sujeto lo porta en A.02 §19.2-U6); (2) numeración canónica confirmada; (3) B14 resuelto por los manuales (coherencia interna 1.09 §7.3 + prueba de consistencia opcional 1.08 §7.2). §9-B7 actualizado a la materialización vigente (enforcement nativo BitMask+PolicyEngine; 5 capas como patrón declarativo de integración vía átomos D1 + biedata — 1.10). Matriz §17.1: **14/14 planos representados** (árbol §17.5 con B20; secuencia ampliada). |


---

## §22 — v2.2.0: El RolTemplate y los átomos de identidad D00 (2026-07-14)

### 22.1 El RolTemplate como fábrica de átomos — incluidos los de identidad

El RolTemplate fabrica átomos. No solo átomos de acceso (D1 leer, D3 aprobar), sino también
átomos de identidad (D00). Los 20 átomos D00 sembrados en `bauth_50__d00_identidad_seeds.sql`
son átomos del mismo `privilege_atom`, se asignan con el mismo `privilege_role_atom`, y el
mismo UserBitMask los evalúa.

```
ROL "vendedor_senior" tiene tickeados:

  D1 · Acceso Lógico              D00 · Identidad
  ─────────────────────           ──────────────
  ✅ d1.zona_ventas.approve       ✅ org.g5.d0.locale        (self-edit)
  ✅ d1.zona_ventas.read          ✅ org.g5.d0.timezone      (self-edit)
  ✅ d3.payment.approve           ☐ org.g5.d0.email         (admin-edit)
  ☐ d3.transfer.execute           ☐ org.g2.d0.nit           (read)

ROL "gerente_regional" tiene tickeados:

  D1 · Acceso Lógico              D00 · Identidad
  ─────────────────────           ──────────────
  ✅ d1.zona_ventas.approve       ✅ org.g5.d0.email         (editar emails del equipo)
  ✅ d3.payment.approve           ✅ org.g2.d0.nit           (ver NIT de la empresa)
  ✅ d3.transfer.execute           ☐ org.g2.d0.direccion    (cambiar dirección fiscal)
```

### 22.2 Atributos del propio rol

Los roles son entidades en `idn_identidad_atributo` con `entidad_tipo='role'`. Tienen atributos
extensibles sin tocar el DDL de `idn_role_template`:

```sql
INSERT INTO bauth.idn_identidad_atributo (entidad_id, category, attr_key, type, value_text) VALUES
  ('vendedor_senior', 'norma', 'respaldo', 'nist', 'NIST SP 800-53 AC-3/AC-6'),
  ('vendedor_senior', 'norma', 'respaldo', 'iso', 'ISO 27001:2022 A.5.15'),
  ('vendedor_senior', 'seguridad', 'loa_required', NULL, '2'),
  ('vendedor_senior', 'seguridad', 'mfa_required', NULL, 'true'),
  ('vendedor_senior', 'sector', 'caeb', 'primario', 'COMERCIAL');
```

### 22.3 Conjuntos de roles (D98) y conjuntos de usuarios (D94)

El RolTemplate ya incluye D98 (conjuntos de roles). La arquitectura v2.0 agrega D94
(conjuntos de usuarios). Ambos usan el mismo patrón:

```
D98 · SET(financieros_tier2)  → {analista_pagos, contador_junior}
D98 · SET(vendedores)         → {vendedor_senior, vendedor_junior, ejecutivo_ventas}

D94 · USERSET(RRHH)           → todos los actores HUMAN empleados
D94 · USERSET(flota)          → todos los actores tipo=vehiculo
D94 · USERSET(autenticacion)  → todos los actores que pueden loguearse
```

### 22.4 Conexión con el motor de identidad

Los átomos D00 son validados por el motor de identidad (2.15) antes de ser asignados a
roles. La validación del dato (¿el NIT tiene 14 dígitos?) ocurre en el motor de identidad.
La gobernanza del acceso (¿Juan puede ver el NIT?) ocurre en el BitMask. Dos motores,
mismo lenguaje AtomLang, mismos átomos.

---

## Historial (continuación)

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 2.2.0 | 2026-07-14 | **Átomos de identidad D00 en el RolTemplate.** Nueva §22: el RolTemplate fabrica átomos D00 además de D1-D13. Atributos del propio rol en idn_identidad_atributo. Conjuntos de usuarios (D94). Conexión con el motor de identidad (2.15). |
