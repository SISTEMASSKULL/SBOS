---
name: bauth-ddl
description: >
  La base de datos de bAuth: DDL V2 de SBOS_db, sus 12 secciones (S1-S12), 190+ tablas,
  inventario de diseño A.65.02 (T-NNN con nombre y propósito), convenciones de diseño,
  y la definición canónica de dominios/bloques (D00-D15 + D98 + D99 via A.65.03.01).
  Úsala cuando vayas a consultar, modificar o verificar el esquema de la base de datos
  de bAuth, trabajar con seeds/migrations, o entender la estructura de almacenamiento
  de identidades, roles, políticas, sesiones o auditoría.
---

# Skill — bAuth: DDL y Base de Datos

**Fuente de verdad del schema:** `SBOS_db_V2_DDL.sql` + `SBOS_db_V2_DDL_MANUAL.md`  
**Versión DDL:** 2.7.0 · 2026-07-28  
**Motor:** PostgreSQL 18.4 · UUIDv7 (RFC 9562) · `gen_ulid()` para orden de inserción

---

## 1 · Archivos canónicos del DDL

| Archivo | Ruta absoluta | Rol |
|---------|--------------|-----|
| DDL completo | `/opt/skull/orquestador/proyectos/SBOS/DDLs/SBOS_db_V2_DDL.sql` | Esquema SQL ejecutable — fuente de verdad estructural |
| Manual del DDL | `/opt/skull/orquestador/proyectos/SBOS/DDLs/SBOS_db_V2_DDL_MANUAL.md` | La intención detrás de cada decisión — **leer junto al DDL** |
| Inventario de diseño | `context/Documentacion/anexos/A.65.02_ANEXO-NUEVA-DDL-v1.0.md` | Inventario canónico de tablas V2 — T-NNN con nombre definitivo + propósito (v1.6, 2026-07-28) |
| Dominios y bloques | `context/Documentacion/anexos/A.65.03.01_FORMALIZACION-DOMINIOS-BLOQUES-CANONICOS-v1.0.md` | 134 bloques · 18 dominios — SSOT normativo de bloques |

**Regla:** nunca consultar el DDL sin leer también el manual. El DDL define la estructura; el manual define la intención y los invariantes que los constraints protegen. A.65.02 es el inventario de diseño que explica el PARA QUÉ de cada tabla.

---

## 2 · Bases de datos

| Entorno | Nombre BD | Notas |
|---------|-----------|-------|
| VPS pruebas | `SBOSDB` | PostgreSQL 18.4 en la VPS de pruebas — donde se verifica todo |
| Producción | `SBOS_db` | Nombre canónico (igual que el archivo DDL) |
| Fábrica (meta) | `SKDATA` (puerto 5402) | **DISTINTO** — es la BD de la fábrica para tracking de agentes; NO es la BD de bAuth |

> **Importante:** `SKDATA` es para la bitácora de agentes (fábrica). `SBOSDB` / `SBOS_db` es la BD operativa de bAuth (identidades, roles, sesiones, auditoría).

---

## 3 · Estructura del DDL — 12 Secciones (S1-S12)

| Sección | Schema | Contenido | LEVELS |
|---------|--------|-----------|--------|
| **S1** | `bglobal` | Configuración global del sistema — cryptography, geo, settings | 0–2 |
| **S2** | `btenant` | Tenants y sub-tenants — multi-tenancy raíz | 2–3 |
| **S3** | `bcalendar` | Calendarios, horarios, feriados — integración bCalendar | 1–3 |
| **S4** | `bauth.roles_*` | Roles y DAG de herencia — PrivilegeEngine | 1–6 |
| **S5** | `bauth.version_*` | Versionado universal — temporal constraints PG18 | 1–5 |
| **S6** | `bauth.policy_*` | Árbol de políticas — PolicyEngine / AtomLang | 1–6 |
| **S7** | `bauth.idn_*` | Identidad D00 — árbol organizacional, usuarios, atributos | 1–7 |
| **S8** | `bauth.priv_*` | Privilegios — átomos, BitMask Dual, DomainRegistry | 1–8 |
| **S9** | `bauth.session_*` | Sesiones, Context Plane, tokens, ctx_id | 1–7 |
| **S10** | `bauth.audit_*` | Auditoría WORM — events, IGA, trazabilidad | 1–8 |
| **S11** | `bauth.risk_*` | Riesgo e ITDR — anomalías, scoring, alertas | 1–6 |
| **S12** | `bauth.pam_*` | PAM — acceso privilegiado, check-out de credenciales | 1–6 |

**190+ tablas** numeradas T-001 → T-194+. LEVELS indican orden de dependencia (0 = sin FK externos, 11 = máximo anidamiento).

---

## 4 · Convenciones del DDL

### Símbolos del manual

| Símbolo | Significado |
|---------|-------------|
| 🔑 | Primary Key |
| 🔗 | Foreign Key |
| 🔒 | WORM (Write Once Read Many) — prohibido UPDATE/DELETE por RSP |
| 📦 | Tabla particionada |
| 🌱 | Tabla con datos seed (datos iniciales obligatorios) |
| ⚡ | Trigger asociado |
| 🔄 | Tabla replicada |

### Reglas de diseño obligatorias (del DDL manual)

- **UUIDv7** (RFC 9562) como PK en todas las tablas de entidad — orden temporal sin clock externo.
- **`gen_ulid()`** para IDs de inserción ordenada en tablas de alta escritura.
- **`DEFAULT now()`** en `created_at`; `updated_at` manejado por trigger `set_updated_at`.
- **Row Security Policy (RSP)** en todas las tablas de datos sensibles — aislamiento multi-tenant.
- **WORM en tablas de auditoría** — `bauth.audit_*` son append-only por RSP; ningún UPDATE/DELETE posible.
- **`bit_slot` inmutable** — una vez asignado a un átomo, nunca se reasigna aunque el átomo sea deprecado (preserva coherencia histórica del audit log).

---

## 5 · Dominios y Bloques de bAuth (A.65.03.01)

**Documento:** `context/Documentacion/anexos/A.65.03.01_FORMALIZACION-DOMINIOS-BLOQUES-CANONICOS-v1.0.md`  
**SSOT de bloques:** `bauth.idn_roles_template` en SBOSDB (verificado 2026-07-28)  
**Total:** 134 bloques · 18 dominios · depth=2 en el árbol de roles

| Dominio | Código | Bloques | Propósito |
|---------|--------|---------|-----------|
| D00 · Identidad Organizacional | `d00` | 9 | Árbol org (tenant→bdomain→pos→actor), atributos |
| D01 · Control de Acceso Lógico | `d01` | 9 | Permisos clásicos de aplicación |
| D02 · Control de Acceso Físico | `d02` | 8 | Acceso físico, zonas, puertas |
| D03 · Controles Financieros | `d03` | 9 | Límites, aprobaciones, montos |
| D04 · Acceso Temporal | `d04` | 6 | Horarios, ventanas, restricciones de tiempo |
| D05 · Autenticación Biométrica | `d05` | 7 | Biometría, liveness, matching |
| D06 · Acceso Geoespacial | `d06` | 6 | Zona GPS, geofencing |
| D07 · Seguridad de Red | `d07` | 8 | IP, subnet, protocolo, VPN |
| D08 · Contexto / Sesión | `d08` | 7 | ctx_id, estado sesión, device posture |
| D09 · Gestión de Credenciales | `d09` | 10 | Ciclo vida credenciales, rotación, revocación |
| D10 · Delegación e Impersonación | `d10` | 7 | Actuar en nombre de otro, proxy |
| D11 · Auditoría y Cumplimiento | `d11` | 7 | Registro WORM, IGA, conformidad |
| D12 · Anclaje Blockchain | `d12` | 7 | ECDSA en Besu, registro inmutable |
| D13 · Firma Digital Externa | `d13` | 8 | ADSIB RSA-SHA256, Ley 164 Bolivia |
| D14 · Gestión de Acceso Privilegiado | `d14` | 7 | PAM, checkout credenciales críticas |
| D15 · Identidad No Humana (NHI) | `d15` | 8 | M2M, service accounts, API keys |
| D98 · Registro Estructural | `d98` | 4 | Metadatos de estructura interna |
| D99 · Administración Global | `d99` | 7 | bglobal, criptografía de atributos, versionado normas |

**Estado actual de todos los bloques: ⬜** — existen a depth=2 en la BD, sin átomos poblados.  
El trabajo pendiente es poblar los átomos (depth≥3), no crear los bloques.

---

## 6 · Inventario de diseño DDL (A.65.02)

**Documento:** `context/Documentacion/anexos/A.65.02_ANEXO-NUEVA-DDL-v1.0.md` (v1.6 · 2026-07-28)  
**Estado:** DISEÑO PARCIAL — 9 secciones completas · 4 pendientes (USUARIOS · AUTENTICACIÓN · FIRMA DIGITAL · FEDERACIÓN/OIDC)

A.65.02 es el inventario limpio del rediseño completo del DDL. Código T-NNN + nombre canónico definitivo + propósito. **Es el "para qué" de cada tabla**; el DDL SQL es el "cómo".

### GLOBAL — `bglobal.*` — catálogos ISO y parámetros del sistema

| T | Tabla | Propósito |
|---|-------|-----------|
| T-001 | `bglobal.global_language` | Catálogo ISO 639-1/3 de idiomas |
| T-002 | `bglobal.global_country` | Catálogo ISO 3166-1 de países |
| T-003 | `bglobal.global_currency` | Catálogo ISO 4217 de monedas |
| T-004 | `bglobal.geo_timezone` | Catálogo IANA de zonas horarias |
| T-059 | `bglobal.menu_item` | Ítems de menú del dashboard por módulo |
| T-060 | `bglobal.menu_context` | Agrupa ítems de menú por contexto de rol/dominio |
| T-061 | `bglobal.menu_item_atom` | Puente menú ↔ motor BitMask (visibilidad B7 CAPA 2) |
| T-114 | `bglobal.global_config` | Parámetros globales del sistema — `scope='global'` del PIP `@bauth_config_param` |

### TENANT — `bauth.idn_tenant*` — multi-tenancy raíz

| T | Tabla | Propósito |
|---|-------|-----------|
| T-005 | `bauth.idn_tenant` | Ancla de gobernanza — toda FK del DDL arranca desde `tenant_id` |
| T-006 | `bauth.idn_tenant_currencies` | Monedas habilitadas por tenant |
| T-007 | `bauth.idn_tenant_languages` | Idiomas disponibles en el dashboard y APIs |
| T-008 | `bauth.idn_tenant_verification` | Nivel IAL alcanzado por el tenant (documentos validados) |
| T-009 | `bauth.idn_tenant_config` | Configuración por tenant — fuente del PIP `@bauth_config_param` (techo/piso por organización) |
| T-010 | `bauth.idn_tenant_domain` | Dominios DNS del tenant — prefijo del `ctx_id` (SBOS-049 §3.1) |
| T-011 | `bauth.idn_tenant_network` | CIDRs permitidos por tenant — validados por PEP en D7 |
| T-013 | `bauth.idn_tenant_calendar_assignment` | Calendarios asignados al tenant — condicionan validez temporal de roles |

> **PIP `@bauth_config_param`**: resuelto en cascada: primero T-009 (tenant), luego T-114 (global). No hay tabla `bauth_config_param` separada.

### ROLES — `bauth.idn_roles_*` — identidad de roles y árbol de políticas

| T | Tabla | Propósito |
|---|-------|-----------|
| T-040 | `bauth.idn_roles_rol_type` | Catálogo de tipos de cuenta: 10 tipos (INDIVIDUAL · M2M · SYSTEM · GROUP · TEMPLATE · VIRTUAL · BOT · DEVICE · SERVICE · EMERGENCY) |
| T-041 | `bauth.idn_roles_rol_hierarchical` | Árbol de 548 roles con jerarquía parent/child, tier, status, versión. **El QUIÉN del sistema.** B02: vigencia + trigger `trg_irrh_b02_validity` |
| T-042 | `bauth.idn_roles_rol_tier` | Parámetros de autenticación por tier — LOA requerido, métodos MFA, timeouts, max_sessions, step-up, AAL |
| T-063 | `bauth.idn_roles_rol_closure` | Closure table del DAG de herencia — materializa rutas ancestro→descendiente para máscara BitMask acumulada en O(1) |
| T-161b | `bauth.idn_roles_template_tipo_nodo` | Catálogo de tipos de nodo del árbol de políticas — color, fuente, badge para Flutter (reemplaza CHECK en T-162) |
| T-162 | `bauth.idn_roles_template` | **Árbol jerárquico de políticas** — UN árbol compartido: dominio·bloque·política·regla·evaluación·átomo·obligación. Contiene `atom_position`. **El QUÉ PUEDE el sistema.** |
| T-163 | `bauth.idn_roles_template_history` | Historial WORM del árbol T-162 — trazabilidad forense de cada cambio |
| T-194 | `bauth.idn_roles_iga_category` | Categorías IGA: 7 tipos (BUSINESS · IT_INFRA · APPLICATION · PRIVILEGED · EMERGENCY · SERVICE · STANDARD). Define `review_cycle_days` y `is_privileged` |
| T-B02L | `bauth.idn_roles_rol_lifecycle_event` | Log WORM de transiciones de estado del rol (MANUAL/AUTO_EXPIRY/RECONCILE/IGA_REVIEW/BREAKGLASS/BOOTSTRAP) |

### VERSIONADO — `bauth.idn_roles_ver_*` — Motor de Versionado Universal (MVU 1.13)

| T | Tabla | Propósito |
|---|-------|-----------|
| T-152 | `bauth.idn_roles_ver_b01_audit_log` | Historia WORM de versiones cerradas de T-041. `WITHOUT OVERLAPS` PG18 + btree_gist. REVOKE UPDATE/DELETE |
| T-153 | `bauth.idn_roles_ver_b03_approval_queue` | Cola de cambios MAJOR pendientes de quórum N-de-M — dual control (`resolved_by ≠ proposed_by`) |
| T-154 | `bauth.idn_roles_ver_b01_retention_policy` | Política de retención legal — `hot_window`, `compaction_policy`, piso ≥ 365 días. `legal_hold=true` suspende purga |
| T-155 | `bauth.idn_roles_ver_contract_revision_log` | Changelog estructural del contrato RolTemplate (v5.0→v6.0) — append-only histórico |

### IDENTIDAD — `bauth.idn_identidad_*` — Motor de Identidad D00 v2.0

| T | Tabla | Propósito |
|---|-------|-----------|
| T-156 | `bauth.idn_identidad_entidad` | Catálogo universal de actores — árbol 5 niveles: `tenant→bdomain→bsubdomain→pos→actor` |
| T-157 | `bauth.idn_identidad_atributo` | Atributos EAV extensibles — NIT, razón social, correos, teléfonos, documentos, códigos SIN. `atom_code` vincula con BitMask |
| T-158 | `bauth.idn_identidad_atributo_history` | Historial WORM de cambios de atributos — hash-chain SHA-256, particionado por mes. REVOKE UPDATE/DELETE ✅ |
| T-159 | `bauth.idn_identidad_requisito` | Completitud mínima por tipo de entidad y nivel IAL — 8 seeds Bolivia ✅ |
| T-160 | `bauth.idn_identidad_sinonimo` | Sinónimos/abreviaturas para búsqueda difusa — archivos `.syn` de PostgreSQL |
| T-161 | `bauth.idn_identidad_sinonimo_sync` | Control de sincronización de diccionarios `.syn` |
| T-165 | `bauth.idn_identidad_proofing` | Identity Proofing por actor — tipo, evidencias FAIR/STRONG/SUPERIOR (NIST SP 800-63A-4), IAL alcanzado ✅ |
| T-166 | `bauth.idn_identidad_consentimiento` | WORM de consentimiento GDPR + Ley 1174 Bolivia. REVOKE DELETE ✅ |
| T-167 | `bauth.idn_identidad_vc` | Ciclo de vida de Verifiable Credentials — W3C VCDM 2.0, SD-JWT VC, VC Status List 2021 ✅ |
| T-168 | `bauth.idn_tenant_fal_config` | Configuración FAL por Relying Party — FAL1/FAL2 (DPoP)/FAL3 (mTLS) ✅ |

**NHI — Identidades No-Humanas (daemons, pipelines, agentes IA):**

| T | Tabla | Propósito |
|---|-------|-----------|
| T-186 | `bauth.idn_roles_nhi_identity` | Entidad raíz de toda identidad máquina. `owner_id` = humano responsable. Seeds: un NHI por daemon SBOS ✅ G-21 |
| T-187 | `bauth.idn_roles_nhi_lifecycle_event` | Log WORM de eventos NHI — PROVISIONED/CERTIFIED/ROTATED/SUSPENDED/DECOMMISSIONED ✅ G-22 |
| T-188 | `bauth.idn_roles_nhi_certification` | Certificación periódica mensual del NHI — evidencia de revisión del propietario ✅ G-22 |
| T-190 | `bauth.idn_roles_nhi_agent_identity` | NHI para agentes IA — `max_permission_scope`, `orchestrator_id`, `can_spawn_agents`, `max_spawn_depth`. ⚠️ BLOQUEADO: herencia padre→hijo (HITL pendiente) ✅ G-24 |

### CALENDARIO — `bcalendar.*` — infraestructura temporal

| T | Tabla | Propósito |
|---|-------|-----------|
| T-012 | `bcalendar.cal_fiscal_year` | Años fiscales por tenant |
| T-014 | `bcalendar.cal_calendar` | Calendarios laborales — nombre, zona horaria, reglas base |
| T-015 | `bcalendar.cal_event` | Eventos especiales que afectan ventanas de acceso |
| T-016 | `bcalendar.cal_alarm` | Alarmas D4 — alerta 30 días antes del vencimiento del rol |
| T-017 | `bcalendar.cal_notification_log` | Log de notificaciones de calendario vía bNotify |
| T-018 | `bcalendar.cal_holiday` | Días festivos bolivianos + propios del tenant |
| T-019 | `bcalendar.cal_schedule` | Horarios laborales (ventanas horarias por tenant/turno) |
| T-124 | `bcalendar.cal_overtime_policy` | Políticas de horas extra — override de emergencia en D3 |
| T-125 | `bcalendar.cal_break_policy` | Políticas de descanso — suspensión de sesiones activas |

### USUARIOS — pendiente de diseño

*(Tablas por definir — separación NIST SP 800-63-4 §3: identity D00 · subscriber account aquí · authenticator en AUTENTICACIÓN)*

### AUTENTICACIÓN — pendiente de diseño

*(47 métodos en 6 categorías — 9 implementados hoy. Incluirá framework declarativo de 7 tablas: `auth_method`, `auth_policy`, `auth_config`, `crypto_algorithm`, `federation_protocol`, `saga_catalog`, `compliance_map`)*

### SESIÓN — `bauth.ses_*` — Context Plane y ciclo de vida de sesiones

| T | Tabla | Propósito |
|---|-------|-----------|
| T-181 | `bauth.ses_session_log` | Historial forense de sesiones — complementa Redis (store activo). `loa_initial`, `loa_peak`, `termination_reason` ✅ G-16 |
| T-191 | `bauth.ses_caep_event_log` | Log WORM de eventos CAEP entrantes — `grants_affected[]`, estado procesamiento ✅ G-25 |
| T-192 | `bauth.ses_ssf_stream` | Configuración de streams SSF — endpoint, delivery_method, `auth_vault_path` (nunca el secreto) ✅ G-26 |
| T-193 | `bauth.ses_ssf_delivery_log` | Log WORM de intentos de entrega por stream SSF ✅ G-26 |

### PRIVILEGIOS — `bauth.privilege_*` — Motor BitMask (PAP/PDP/PEP/PIP)

| T | Tabla | Propósito |
|---|-------|-----------|
| T-170 | `bauth.privilege_atom_grant` | Grants **per-user** (no por rol) — una fila por usuario×átomo. Lee `atom_position` de T-162 vía FK compuesta. `grant_type`: STANDARD · JIT · BREAKGLASS ✅ G-09/G-20 |
| T-170b | `bauth.privilege_atom_audit` | WORM append-only hash-chain de cada INSERT/UPDATE en T-170 (ISO 27001 A.8.15). REVOKE UPDATE/DELETE |
| T-171 | `bauth.privilege_resource_atom` | Mapeo PAP per-tenant: `(tenant_id + protocolo + recurso + operación)` → `id_atom`. Obligation JSONB si requiere LoA ✅ G-06 |
| T-172 | `bauth.privilege_delegation` | Solo auditoría y trazabilidad de delegaciones — quién autorizó qué asignación y por qué ✅ G-08 |
| T-173 | `bauth.privilege_override` | Excepciones DENY→PERMIT/PERMIT→DENY per-tenant. `approver_id`+`reason`+`valid_until` obligatorios ✅ G-06 |
| T-174 | `bauth.privilege_verb` | Catálogo de verbos válidos. **Solo validación** — FK de `idn_roles_template.verb_id`. No participa en BitMask |
| T-175 | `bauth.privilege_verb_conflict` | Matriz de conflictividad SoD entre pares de verbos. **Solo validación** — consultada por trigger T-170 y compilador AtomLang |
| T-176 | `bauth.privilege_assurance_audit` | Auditoría de evaluaciones de LoA — poblada por Kong (PEP). T-170b audita qué se otorgó; T-176 audita cómo se ejerció ✅ G-04 |
| T-179 | `bauth.privilege_exception_record` | Gobernanza de excepciones a políticas — contexto de aprobación detrás de cada override en T-173. Job diario expira excepciones vencidas ✅ G-14 |

### AUDITORÍA — `bauth.aud_*` — WORM forense IGA

| T | Tabla | Propósito |
|---|-------|-----------|
| T-177 | `bauth.aud_certification_campaign` | Campaña de certificación IGA — scope (TENANT/USER/ROLE/ATOM), tipo (QUARTERLY/ANNUAL…), ventana y responsable. WORM ✅ G-13 |
| T-178 | `bauth.aud_certification_review` | Evidencia auditable por (campaña, grant) — decisión CERTIFY/REVOKE/ESCALATE/DEFER. `decision='REVOKE'` actualiza T-170 ✅ G-13 |

### FIRMA DIGITAL — pendiente de diseño

*(Motor interno Vault Ed25519 + Motor externo ADSIB RSA-SHA256, Ley 164 Bolivia. Los átomos D13 llevan `blockchain_anchored=1` para anclaje en D12 Besu)*

### FEDERACIÓN / OIDC — pendiente de diseño

*(OIDC Provider propio de bAuth — ADR-010. Relying parties, IdPs federados, OAuth2 tokens, PKCE, DPoP, FAPI 2.0)*

### RIESGO / ITDR — `bauth.ses_risk_*` / `bauth.ses_*`

| T | Tabla | Propósito |
|---|-------|-----------|
| T-180 | `bauth.ses_risk_policy` | Reglas de política de riesgo adaptativo por tenant — `trigger_event` × `condition` JSONB × `action` (STEP_UP/REVOKE/SUSPEND/NOTIFY/REQUIRE_MFA). Editable en runtime sin recompilar ✅ G-15 |

### PAM — `bauth.pam_*` — Gestión de Acceso Privilegiado

| T | Tabla | Propósito |
|---|-------|-----------|
| T-182 | `bauth.pam_jit_request` | Solicitud JIT (Zero Standing Privilege) — workflow: PENDING→APPROVED→ACTIVE→EXPIRED/REVOKED. `justification` ≥ 50 chars. WORM ✅ G-17 |
| T-182b | `bauth.pam_jit_approval` | Aprobación secuencial multi-nivel — una fila por nivel. Nivel 2 notificado solo cuando Nivel 1 aprueba ✅ G-17 |
| T-183 | `bauth.pam_credential_ref` | Referencias a credenciales privilegiadas en Vault — NUNCA el valor. Cubre humanos y NHI ✅ G-18 |
| T-184 | `bauth.pam_session_record` | Metadatos de sesión privilegiada — tipo de acceso, comandos, referencia a grabación en MinIO ✅ G-19 |
| T-185 | `bauth.pam_breakglass_activation` | Ciclo de vida break-glass — dual control obligatorio, AAL3, TTL 4h, máx. 2 BREAKGLASS activos por tenant ✅ G-20 |
| T-189 | `bauth.pam_nhi_secret_ref` | Referencias a secretos NHI en Vault — rotación 7-30 días. `rotation_policy='ON_USE'` para pipelines CI/CD ✅ G-23 |

---

**Decisiones arquitectónicas (A.65.02 — no inferir del DDL SQL):**
- `atom_position` está en **T-162** (árbol de políticas) vía SEQUENCE `roles_atom_position_sequential` — **no** en T-170.
- **T-170** es grants **per-user**, no per-rol. SET/UNSET de AtomLang materializa filas individuales.
- **SoD** (G-03) es solo validación en T-174/T-175 — trigger en T-170 verifica al INSERT. No participa en BitMask.
- **T-170b** es WORM separado de T-170 para garantizar inmutabilidad real (ISO 27001 A.8.15).
- **T-176** audita cómo se ejerció el privilegio (Kong); **T-170b** audita qué se otorgó (bAuth) — son distintos.
- Schema `bglobal` para catálogos compartidos por todo el ecosistema SBOS.
- **`@bauth_config_param`**: no es tabla — es referencia PIP resuelta en cascada T-009 → T-114.
- **Decisión HITL pendiente** en IDENTIDAD: modelo de 25 metadatos de `idn_identidad_atributo` (Opción A: columnas directas · Opción B: tabla catálogo separada).

---

## 7 · Tablas clave para bAuth

```sql
-- Bloques de dominios (SSOT de blocks)
bauth.idn_roles_template       -- 134 bloques · depth=2 · SSOT de qué bloques existen

-- Árbol organizacional
bauth.idn_tenant               -- Tenants
bauth.idn_bdomain              -- Business domains dentro del tenant
bauth.idn_identity             -- Identidades (personas, M2M)

-- Roles y privilegios
bauth.roles_template           -- RolTemplate v6.0 — 14 bloques JSONB
bauth.priv_atom                -- Catálogo de átomos (~6,000 definidos)
bauth.priv_bitmask             -- BitMask Dual por identidad/dominio

-- Sesiones
bauth.session_ctx              -- Context Plane — ctx_id activos
bauth.session_token            -- Tokens JWT emitidos

-- Auditoría (WORM)
bauth.audit_event              -- Log WORM de todos los eventos de identidad
```

---

## 8 · Cómo trabajar con el DDL

```bash
# Verificar conexión a SBOSDB (VPS pruebas)
psql "postgresql://<user>@<vps-host>:5432/SBOSDB" -c "\dt bauth.*" | head -20

# Ver estructura de una tabla
psql "postgresql://<user>@<vps-host>:5432/SBOSDB" -c "\d bauth.idn_roles_template"

# Contar bloques por dominio
psql "postgresql://<user>@<vps-host>:5432/SBOSDB" -c \
  "SELECT split_part(clave,'.',1) AS dominio, count(*) AS bloques
   FROM bauth.idn_roles_template WHERE tipo='bloque' GROUP BY 1 ORDER BY 1;"
```

**Antes de proponer cualquier cambio al DDL:**
1. Leer el manual (`SBOS_db_V2_DDL_MANUAL.md`) para entender el invariante que cada constraint protege.
2. Verificar que el cambio no rompe ningún RSP existente.
3. Verificar que el `bit_slot` de ningún átomo activo o histórico sea reasignado.
4. Escalar al humano si el cambio afecta tablas WORM o PKs existentes.
