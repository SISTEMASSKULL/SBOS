# SBOS_db_V2_DDL_MANUAL.md
## Manual Operativo de la Base de Datos — SBOS Identity Platform V2

**Versión:** 2.12.0 · **Fecha:** 2026-07-31  
**Base de datos:** `SBOS_db` · **PostgreSQL:** 18.4 · **UUIDv7:** RFC 9562  
**Estándar de documentación:** ISO/IEC 11179 · DAMA DMBOK v2 · ISO 24760-2:2025  
**Sincronizado con:** `SBOS_db_V2_DDL.sql` (NIVEL 0..19) — nombres canónicos del DDL

---

## Índice de Secciones

| Sección (DDL NIVEL) | Tablas DDL (nombres canónicos) | Descripción |
|---------------------|-------------------------------|-------------|
| [S1 — Global](#s1--catálogos-globales-bglobal) (NIVEL 0) | T-001..T-004, T-059, T-060, T-061, T-114 | Catálogos ISO compartidos |
| [S2 — Tenant](#s2--infraestructura-tenant-bauth) (NIVEL 1) | T-005..T-011, T-013 | Multi-tenancy base |
| [S3 — Calendario](#s3--calendario-bcalendar) (NIVEL 2) | T-012, T-014..T-019, T-124, T-125 | Calendario fiscal y turnos |
| [S4 — Roles](#s4--roles-bauth) (NIVEL 3) | T-040..T-042, T-063, T-161b, T-194, T-B02L | Catálogo, jerarquía, tipos de nodo, IGA y lifecycle B02 |
| [S5 — Versionado](#s5--versionado-bauth) (NIVEL 4) | T-152..T-155 | Motor de Versionado B01/B03 (MVU 1.13) |
| [S6 — Árbol de políticas](#s6--árbol-de-políticas-bauth) (NIVEL 5) | T-162, T-163, T-174, T-175 | XACML/RBAC N3 PAP |
| [S7 — Identidad D00](#s7--identidad-d00-bauth) (NIVEL 6) | T-156, T-157, ✅T-158, ✅T-159, ✅T-165, ✅T-166, ✅T-167, ✅T-168, ✅T-169, ✅T-186, ✅T-187, ✅T-188, T-160..T-161, T-190 | Jerarquía de entidades + esquema IAL + proofing + consentimiento + VC + FAL + NHI + DID + JML + SCIM + DPIA |
| [S8 — Privilegios](#s8--privilegios-bauth) (NIVEL 7) | T-170, T-170b, T-171(`privilege_resource_atom`), T-172(`privilege_delegation`), T-173(`privilege_override`), T-176(`privilege_assurance_audit`), T-179(`privilege_exception_record`) | Grants, recursos, overrides, SoD |
| [S9 — Sesión](#s9--sesión-bauth) (NIVEL 8) | T-181(`ses_session_log`), T-191(`ses_caep_event_log`), T-192(`ses_ssf_stream`), T-193(`ses_ssf_delivery_log`) | Sesiones + CAEP + SSF |
| [S10 — Auditoría](#s10--auditoría-access-review-bauth) (NIVEL 9) | T-177(`aud_certification_campaign`), T-178(`aud_certification_review`) | Campañas de certificación IGA |
| [S11 — Riesgo / ITDR](#s11--riesgo--itdr-bauth) (NIVEL 10) | T-180(`ses_risk_policy`) | Políticas de riesgo adaptativo |
| [S12 — PAM](#s12--pam-privileged-access-management-bauth) (NIVEL 11) | T-182(`pam_jit_request`), T-182b(`pam_jit_approval`), T-183(`pam_credential_ref`), T-184(`pam_session_record`), T-185(`pam_breakglass_activation`), T-189(`pam_nhi_secret_ref`) | JIT, Break-glass, Vault, NHI |
| [S13 — Usuarios](#s13--usuarios-bauth) (NIVEL 12) | T-320(`idn_user`), T-321(`idn_user_history`), T-322(`idn_user_recovery`) | Subscriber Account NIST SP 800-63-4 · SCIM 2.0 |
| [S14 — Autenticación](#s14--autenticación-bauth) (NIVEL 13) | T-330..T-338 (auth_credential, _secret, _fido2, _x509, _attempt_log, auth_method, auth_policy, auth_config, auth_crypto_algorithm) | MethodRegistry declarativo · FIDO2 · X.509 · Catálogo |
| [S15 — Firma Digital D13](#s15--firma-digital-d13-bauth) (NIVEL 14) | T-350..T-357 (sig_key, sig_certificate, sig_crl, sig_timestamp, sig_operation_log, sig_document_hash, sig_adsib_lifecycle, sig_document_policy) | Ley 164 Bolivia · ADSIB · eIDAS 2.0 · RFC 5280 |
| [D12 — Blockchain](#d12--blockchain-bauth) (NIVEL 15) | T-358..T-362 (blk_anchor, blk_merkle_batch, blk_merkle_leaf, blk_account, blk_reconciliation) | Merkle WORM · Arbitrum L2 · Besu QBFT |
| [S16 — Federación / OIDC](#s16--federación--oidc-bauth) (NIVEL 16) | T-365..T-367 (fed_client, fed_provider_ext, fed_token_issued) | RFC 6749/9449 DPoP · FAPI 2.0 · SAML 2.0 |
| [S17 — Billetera Digital](#s17--billetera-digital-bauth) (NIVEL 17) | T-380..T-383 (wallet, wallet_item, wallet_presentation_log, wallet_issuance_log) | EUDI Wallet · W3C VCDM 2.0 · OID4VP · OpenID4VCI |
| [S14 catálogos — MethodRegistry](#s14-catálogos--methodregistry-bauth) (NIVEL 18) | T-384(`auth_federation_protocol`), T-385(`auth_saga_catalog`), T-386(`auth_compliance_map`) | 8+12+14 seeds · protocolos · sagas · cobertura normativa |
| [S18 — Dispositivos](#s18--dispositivos-bauth) (NIVEL 19) | T-390(`auth_device`), T-391(`auth_device_posture`), T-392(`auth_device_credential_binding`) | ZTA · MDM · FIDO2 · OSDP v2.2 · WORM binding |
| [S19 — Context Plane](#s19--context-plane-bos) (NIVEL 20) | T-395(`registered_device`), T-396(`ctx_context_session`), T-397(`ctx_context_audit`), T-398(`ctx_context_switch_log`), T-399(`ctx_context_policy`), T-400(`device_heartbeat`), T-401(`ctx_context_transfer`), T-402(`ctx_context_emergency`) | Policy Administrator NIST SP 800-207 · ctx_id 6 capas · WORM hash-chain |
| [S20 — Biblioteca de Referencia](#s20--biblioteca-de-referencia-bauth) (NIVEL 21) | T-999(`cfg_policy_library`) | Biblioteca unificada de políticas, reglas y átomos — SOLO LECTURA · 16 fuentes · 13 dominios |
| [S20 — BOS Control Plane](#s20--bos-control-plane-bos) (NIVEL 21) | T-403(`fch_ficha_state`), T-404(`fch_ficha_event`), T-405(`ins_bootstrap_event`), T-406(`cap_sistema_snapshot`), T-407(`cap_tenant_policy`), T-408(`prt_port_assignment`), T-409(`rel_release_manifest`), T-410(`rel_release_event`), T-411(`wdg_watchdog_event`), T-412(`ins_saga_execution`), T-413(`net_cert_inventory`), T-414(`net_security_events`) | Fichas · IAM Installer · Capacidad · Port Manager · NetMan (certs + eventos) · Release · Watchdog · Sagas |

> **⚠️ Nota v2.3.0:** S8-S12 fueron refactorizados en el DDL. Los nombres canónicos son los del DDL.
> Tablas ausentes del DDL (pendientes de diseño):
> - `idn_identidad_dominio` (DomainRegistry D01-D37) — no tiene T-code asignado aún
> - `pam_tree_change_proposal` (flujo PAP quórum) — S12 original T-189 en planes; reemplazada por `pam_nhi_secret_ref` en el DDL actual
> - ✅ T-158 (`idn_identity_attribute_history`) — **IMPLEMENTADA v2.5.0** — WORM hash-chain, 6 particiones mensuales. D00-B05.
> - ✅ T-159 (`idn_identity_requirement`) — **IMPLEMENTADA v2.4.0** — esquema de completitud IAL. D00-B03. (+`risk_threshold`, `dirm_policy_ref` v2.7.0)
> - ✅ T-165 (`idn_identity_proofing`) — **IMPLEMENTADA v2.6.0** — Identity Proofing IAL1/IAL2/IAL3. D00-B06. (+`risk_context`, `eidas_level` v2.7.0)
> - ✅ T-166 (`idn_identity_consent`) — **IMPLEMENTADA v2.6.0** — WORM consentimiento GDPR. D00-B07. (+`attr_scope`, `consent_purpose`, `geo_restriction`, `data_categories`, `third_party_sharing`, `retention_end_date` v2.7.0)
> - ✅ T-167 (`idn_identity_vc`) — **IMPLEMENTADA v2.6.0** — Verifiable Credentials W3C VCDM 2.0. D00-B08. (+`eidas_assurance_level`, `eidas_vc_type` v2.7.0)
> - ✅ T-168 (`idn_tenant_fal_config`) — **IMPLEMENTADA v2.6.0** — Federation Assurance Level por RP. D00-B09.
> - ✅ T-169 (`idn_did_document`) — **IMPLEMENTADA v2.7.0** — Caché DID Resolver W3C DID Core v1.1. GAP-D00-05.
> - ✅ T-186 (`idn_identidad_lifecycle_event`) — **IMPLEMENTADA v2.7.0** — JML lifecycle events (Joiner/Mover/Leaver). GAP-D00-02.
> - ✅ T-187 (`idn_scim_attribute_map`) — **IMPLEMENTADA v2.7.0** — Mapeo SCIM 2.0 ↔ atributos locales. RFC 7643/7644. GAP-D00-08.
> - ✅ T-188 (`idn_dpia_registro`) — **IMPLEMENTADA v2.7.0** — Registro DPIA GDPR Art. 35. GAP-D00-10.
> - ✅ T-157 (`idn_identity_attribute`) — extendida v2.7.0: +`classification`, `mutability`, `retention_days`, `uniqueness`, `returned` (GAP-D00-01).
> - T-160..T-161 (`idn_identidad_sinonimo`, `idn_identidad_sinonimo_sync`) — STUBS comentados en el DDL (sin CREATE TABLE)

---

## Convenciones de este manual

| Símbolo | Significado |
|---------|-------------|
| 🔑 PK | Clave primaria (UUIDv7) |
| 🔗 FK | Clave foránea |
| 🔒 WORM | Append-only · REVOKE UPDATE/DELETE |
| 📦 PART | Tabla particionada por mes |
| 🌱 SEED | Tabla con datos semilla en la DDL |
| ⚡ TRIGGER | Lógica automática en INSERT/UPDATE |
| 🔄 REPLICA | REPLICA IDENTITY FULL para WAL/CDC |

---

## S1 — Catálogos Globales (bglobal)

### T-001 · `bglobal.global_language`

**Propósito:** Catálogo canónico de idiomas. Fuente única de verdad de todos los locales BCP 47 del ecosistema SBOS. Evita que cada daemon mantenga su propia lista de idiomas y garantiza coherencia en bi18n.

**¿Qué registra?** Un idioma por fila: código BCP 47, familia ISO 639-1/2/3, script IANA, dirección de texto, estado de activación.

**¿Cuándo se alimenta?** Una sola vez, durante el bootstrap del sistema (migración de datos). Actualizaciones puntuales cuando IANA publica nuevas subetiquetas (infrecuente).

**Relaciones:**
- `idn_tenant_languages.locale` → FK a `global_language.locale`
- `idn_tenant_config.locale_default` referencia el locale
- bi18n daemon consume esta tabla como catálogo base

**Procesos necesarios:**
- Job de sincronización anual con IANA Language Subtag Registry
- bi18n service lo consulta en cache caliente (Redis, TTL 24h)

**¿Necesita interfaz en el frontend?** Sí — selector de idioma en configuración de tenant. El frontend carga solo `WHERE is_active = true` via API bi18n.

**Dependencias:** Ninguna (tabla raíz sin FKs entrantes de schema).

---

### T-002 · `bglobal.global_country`

**Propósito:** Catálogo ISO 3166-1 de países. Referenciado por monedas, zonas horarias, y configuración regional de tenant.

**¿Qué registra?** Código alpha-2, alpha-3, numérico; nombre multi-locale (JSONB CLDR); región/subregión UN M.49; prefijo telefónico; TLD; moneda y zona horaria principal.

**¿Cuándo se alimenta?** Bootstrap. Actualizaciones anuales cuando ISO 3166 cambia (cambios de nombre de país, nuevos países).

**Relaciones:**
- `global_currency.country_id` → FK
- `idn_tenant.country` → código alpha-2

**¿Necesita interfaz en el frontend?** Sí — selector de país en registro de tenant, formularios de dirección.

---

### T-003 · `bglobal.global_currency`

**Propósito:** Catálogo ISO 4217 de monedas. Fuente única de códigos de moneda, símbolo, decimales, y tasa de cambio vs moneda funcional.

**¿Qué registra?** Código ISO, nombre multi-locale, símbolo, número de decimales, país emisor, monedas retiradas (withdrawn_at), criptomonedas (is_cryptocurrency=true).

**¿Cuándo se alimenta?** Bootstrap. Bolivia usa BOB (Boliviano) + USD. El banco central (BCB) alimenta exchange_rate diariamente via job.

**Relaciones:**
- `idn_tenant_currencies.currency_code` → FK NATURAL KEY
- `idn_tenant_config.currency_default` referencia el código

**Procesos necesarios:**
- Job diario de sincronización de tipo de cambio con BCB API (bcb.gob.bo/api/)
- biedata puede ser el puente que ejecuta este job (JSON-RPC)

**¿Necesita interfaz en el frontend?** Sí — configuración de monedas del tenant, reportes financieros.

---

### T-004 · `bglobal.geo_timezone`

**Propósito:** Catálogo IANA TZ Database de zonas horarias. Crítico para calendario, validez temporal de roles y evaluación de horarios de acceso.

**¿Qué registra?** Identificador IANA (America/La_Paz), offset UTC en texto y en minutos (para aritmética), observancia DST, ciudad principal.

**¿Cuándo se alimenta?** Bootstrap. IANA publica actualizaciones varias veces al año (cambios de DST, renombramientos). Job de actualización automática.

**Relaciones:**
- `idn_tenant_config.timezone_default` referencia timezone_id
- `bcalendar.cal_calendar.timezone` referencia timezone_id

**Código:** El Motor de Identidad (D00) usa `utc_offset_min` para aritmética temporal al evaluar condiciones D3/D4 del árbol de políticas.

**¿Necesita interfaz en el frontend?** Sí — selector de zona horaria en configuración de tenant.

---

### T-059 · `bglobal.menu_item`

**Propósito:** Árbol de ítems de menú del dashboard bAuth. Define la navegación del frontend con soporte multi-idioma (JSONB).

**¿Qué registra?** Código único del ítem (dashboard.home, iam.roles.list), label JSONB multi-idioma, ruta frontend, profundidad en el árbol, icono.

**¿Cuándo se alimenta?** Bootstrap del sistema + al agregar nuevas funciones al dashboard. Nunca eliminación — solo is_active=false.

**Relaciones:**
- `bglobal.menu_item_atom(item_id)` — liga el ítem con el átomo de privilegio que lo protege (antes `privilege_menu_atom`, migrada a bglobal)
- `menu_item_context` — liga el ítem con sus contextos de aparición (N:M)
- `parent_id` → auto-referencia (árbol de adyacencia)

**Procesos necesarios:**
- Al crear un nuevo ítem, el administrador DEBE agregar la ligadura en `bglobal.menu_item_atom` para que el PEP de menú lo controle.

**Código:** El frontend consulta el árbol via API `bauth.menu.build` (JSON-RPC) que devuelve solo los ítems con PERMIT en el BitmaskBundle del usuario.

**¿Necesita interfaz en el frontend?** Sí — configurador de menú para administradores del sistema.

---

### T-060 · `bglobal.menu_context`

**Propósito:** Catálogo de contextos de menú (sidebar, toolbar, contextual, quick-actions). Define en qué parte de la UI puede aparecer un ítem.

**¿Qué registra?** Código del contexto, nombre JSONB, tipo de menú (HIERARCHICAL, CONTEXTUAL).

**¿Cuándo se alimenta?** Bootstrap. Raramente cambia — los contextos son estructurales.

**Relaciones:**
- `menu_item_context` — tabla N:M con menu_item

---

### T-061 · `bglobal.menu_item_context`

**Propósito:** Tabla de asociación N:M entre ítems de menú y sus contextos. Un ítem puede aparecer en sidebar Y en quick-actions con sort_order diferente por contexto.

**¿Cuándo se alimenta?** Al registrar o mover ítems de menú entre contextos.

---

### T-114 · `bglobal.global_config`

**Propósito:** Parámetros globales del sistema. Es el **piso** del PIP `@bauth_config_param.*` en el árbol de políticas: si un tenant no tiene el parámetro en `idn_tenant_config.params_policy`, el Motor de Identidad (PDP) cae aquí.

**¿Qué registra?** `param_key` → `param_value`. Aproximadamente 20 parámetros del sistema (A.48): `max_sessions`, `loa_default`, `argon2id_t`, `session_ttl_max`, `mfa_grace_minutes`, etc.

**¿Cuándo se alimenta?** Bootstrap. Solo el administrador SBOS puede modificar estos parámetros (no los tenants).

**Relaciones:**
- `idn_tenant_config.params_policy` → JSONB que puede sobrescribir cada parámetro de global_config para un tenant específico

**Procesos necesarios:**
- Al evaluar `@bauth_config_param.<clave>` en el árbol T-162, el Motor de Identidad:
  1. Busca en `idn_tenant_config.params_policy->>clave` del tenant actual
  2. Si no encuentra → consulta aquí
  3. `is_overridable=false` = el tenant no puede sobrescribir (piso de seguridad)

**Código:** La función PIP del Motor de Identidad: `pip_resolve_config_param(tenant_id, key)`.

**¿Necesita interfaz en el frontend?** Sí — panel de configuración global para administradores SBOS (solo visibles para tier SU/T0).

---

## S2 — Infraestructura Tenant (bauth)

### T-005 · `bauth.idn_tenant`

**Propósito:** Ancla de gobernanza del sistema. TODA FK en la DDL arranca desde `tenant_id`. Sin una fila aquí, ningún recurso puede existir. Es el primer registro que se crea al provisionar un nuevo cliente.

**¿Qué registra?** Identidad legal del tenant, estado del ciclo de vida (7 estados: PENDING_VERIFICATION → ACTIVE → SUSPENDED → MAINTENANCE → SOFT_DELETED → TERMINATED → PURGED), datos legales de Bolivia (tax_id, número de registro), configuración de seguridad base (mfa_required, session_ttl_max, isolation_level), datos de suscripción y plan.

**REPARACIONES vs sbos_00 (ADR-010):**
- ✗ Eliminados: `realm_kc`, `realm_kc_ext` — Keycloak eliminado
- ✗ Eliminados: `namespace_k8s` — K8s es infra de BOS, no de bauth
- ✗ Eliminados: `database_name`, `database_schema` — infra BOS
- ✗ Eliminados: `kong_consumer_id` — Kong PEP config es BOS
- ✓ Agregado: `vault_path` — única referencia de infra que bauth conserva (Vault PKI es nativo)

**¿Cuándo se alimenta?** El daemon BOS (IAM Installer) crea la fila al registrar un nuevo tenant via `bos.tenant.provision` JSON-RPC.

**Relaciones (20+ FKs entrantes):**
- `idn_tenant_currencies`, `idn_tenant_languages`, `idn_tenant_verification`, `idn_tenant_config`, `idn_tenant_domain`, `idn_tenant_network` (config del tenant)
- `idn_roles_rol_hierarchical`, `idn_identity_entity` (identidades del tenant)
- `privilege_atom_grant`, `pam_jit_request`, `pam_breakglass_activation` (PAM)
- `aud_certification_campaign`, `ses_risk_policy` (auditoría/riesgo)
- Todas las tablas bcalendar con `tenant_id`

**Procesos necesarios:**
- BOS Saga de instalación: crea idn_tenant → idn_tenant_config → idn_tenant_verification → idn_roles_rol_tier defaults → idn_roles_template membresía inicial
- Job de purga: `WHERE status = 'TERMINATED' AND purge_after < NOW()` → PURGE y anonimización GDPR

**Código:** Usado en toda query que filtra por tenant. Siempre incluir `tenant_id` en WHERE (RLS Row Level Security en producción).

**¿Necesita interfaz en el frontend?** Sí — panel de administración de tenants para SU/T0.

---

### T-006 · `bauth.idn_tenant_currencies`

**Propósito:** Habilita las monedas que el tenant puede operar. Un tenant boliviano opera con BOB (default) y puede habilitar USD, EUR para operaciones internacionales.

**¿Qué registra?** Moneda habilitada + si es default + tasa de cambio vs moneda funcional + fuente de la tasa (BCB, ECB, MANUAL).

**¿Cuándo se alimenta?** Al registrar el tenant (BOS Saga). Actualizaciones de tasa de cambio: job diario automatizado.

**Procesos necesarios:**
- Job diario: `UPDATE idn_tenant_currencies SET exchange_rate = <BCB_API_RATE>, exchange_updated_at = NOW() WHERE exchange_source = 'BCB'`

**¿Necesita interfaz en el frontend?** Sí — sección "Monedas" en configuración del tenant.

---

### T-007 · `bauth.idn_tenant_languages`

**Propósito:** Idiomas habilitados por tenant. Permite que SBOS genere documentos, notificaciones y UI en los idiomas que el tenant soporta.

**¿Qué registra?** Locale BCP 47, si es default, proveedor de traducción (sbos_i18n, external_api), estado de completitud de la traducción.

**¿Cuándo se alimenta?** Al registrar el tenant. Los tenants bolivianos inician con es-BO (default) + qu-BO (quechua) + ay-BO (aymara).

**¿Necesita interfaz en el frontend?** Sí — sección "Idiomas" en configuración.

---

### T-008 · `bauth.idn_tenant_verification`

**Propósito:** Proceso KYC/IAL del tenant. 5 pasos secuenciales que determinan el nivel IAL del tenant (IAL1=solo declara, IAL2=verificado remotamente, IAL3=verificado presencialmente).

**¿Qué registra?** Un fila por paso por tenant (UNIQUE tenant_id, step). Estado (PENDING/IN_PROGRESS/PASSED/FAILED), evidencia en JSONB, nivel IAL alcanzado, vencimiento de documentos.

**¿Cuándo se alimenta?** Al registrar el tenant (paso IDENTITY_CHECK automático). Los demás pasos los ejecuta el equipo de onboarding SBOS.

**Procesos necesarios:**
- Job de alerta: `WHERE expires_at < NOW() + INTERVAL '30 days'` → notificar vía bNotify que los documentos de verificación están por vencer
- Al completar FINAL_APPROVAL: actualizar `idn_tenant.status = 'ACTIVE'` y `verified_at = NOW()`

**¿Necesita interfaz en el frontend?** Sí — panel de onboarding para el equipo SBOS y checklist de verificación visible al tenant.

---

### T-009 · `bauth.idn_tenant_config`

**Propósito:** Configuración regional del tenant (idioma, zona horaria, moneda, calendario) + parámetros PIP del árbol de políticas. Relación 1:1 con idn_tenant.

**¿Qué registra?** Locale/timezone/moneda default en JSONB (snapshots listos para serializar). Formato de fecha/hora/número. Configuración del calendario fiscal. Parámetros de política (`params_policy` JSONB) que sobrescriben `global_config` para este tenant.

**¿Cuándo se alimenta?** Automáticamente al crear idn_tenant (BOS Saga). El administrador del tenant puede actualizar via `bauth.tenant.config.update`.

**Relaciones:**
- `bglobal.global_language` (via locale_default)
- `bglobal.geo_timezone` (via timezone_default)
- `bglobal.global_currency` (via currency_default)
- `bglobal.global_config` (piso de params_policy)

**Código crítico:** `params_policy` es el primer lugar donde el PIP busca `@bauth_config_param.<clave>`:

```rust
// Motor de Identidad — PIP resolver
async fn pip_config_param(tenant_id: Uuid, key: &str) -> Option<String> {
    // 1. Buscar en idn_tenant_config.params_policy del tenant
    let tenant_val = db.query_opt("SELECT params_policy->>$1 FROM bauth.idn_tenant_config WHERE tenant_id=$2", &[&key, &tenant_id]).await?;
    if let Some(v) = tenant_val { return Some(v); }
    // 2. Fallback: global_config (piso del sistema)
    db.query_opt("SELECT param_value FROM bglobal.global_config WHERE param_key=$1", &[&key]).await
}
```

**¿Necesita interfaz en el frontend?** Sí — "Configuración regional" y "Parámetros de política" en el panel del tenant.

---

### T-010 · `bauth.idn_tenant_domain`

**Propósito:** Dominios DNS del tenant. El dominio primary es la capa 1 del `ctx_id` (SBOS-049). Registra configuraciones de DNS, SSL, CORS y email por dominio.

**REPARACIONES vs sbos_00:**
- ✗ Eliminados: `nginx_config`, `k8s_hpa_config`, `health_config` — infra BOS, no bauth
- ✓ Agregado: `ctx_prefix TEXT` — segmento del ctx_id aportado por este dominio (skull.sbos.bo)

**¿Qué registra?** FQDN único, tipo de dominio (WEB/API/POS/ADMIN/PORTAL), estado de deployment y health, configuraciones en JSONB (dns_config, ssl_config, security_config, redirect_config, email_config, contacts).

**¿Cuándo se alimenta?** Al registrar el tenant. Puede agregarse más dominios (ej: API separado de portal web).

**Procesos necesarios:**
- Verificación DNS: job que valida periódicamente que el dominio resuelve correctamente
- Rotación SSL: trigger via ACME/Let's Encrypt 30 días antes de expirar

**Código:** El `ctx_prefix` se usa al construir el `ctx_id` (SBOS-049 capa 1): `ctx_id = {ctx_prefix}.{session_id}.{operation_id}.{correlation_id}.{user_id}.{timestamp}`.

**¿Necesita interfaz en el frontend?** Sí — sección "Dominios" del panel del tenant.

---

### T-011 · `bauth.idn_tenant_network`

**Propósito:** Redes CIDR autorizadas por tenant para Zero Trust (NIST 800-207). El PEP verifica que el IP del request esté en al menos un CIDR activo del tenant.

**¿Qué registra?** Nombre descriptivo, tipo de red (LAN/WAN/VPN/DMZ/GUEST/MANAGEMENT), CIDR (tipo nativo PG), gateway, DNS servers, VLAN.

**¿Cuándo se alimenta?** Al registrar el tenant (red LAN del cliente). El CTO del cliente registra sus redes adicionales.

**Procesos necesarios:**
- El Motor de Identidad valida: `SELECT 1 FROM idn_tenant_network WHERE tenant_id=$1 AND cidr >>= $2::inet AND is_active=true`
- {} en `allowed_ip_ranges` de idn_tenant = sin restricción de red

**¿Necesita interfaz en el frontend?** Sí — sección "Redes" para administradores T1/BIZ_N1.

---

### T-013 · `bauth.idn_tenant_calendar_assignment`

**Propósito:** Puente entre entidades bauth y calendarios bcalendar. Implementa herencia jerárquica: el tenant asigna un calendario, las empresas lo heredan, las sucursales lo heredan.

**REPARACIÓN vs sbos_00:** calendar_id ahora tiene FK real a `bcalendar.cal_calendar` (antes era UUID huérfano sin constraint).

**¿Qué registra?** (calendar_id, owner_type, owner_id) UNIQUE. Role: OWNER puede gestionar, EDITOR modifica eventos, VIEWER solo lee.

**¿Cuándo se alimenta?** Al crear un tenant/empresa/sucursal, BOS Saga crea la asignación del calendario fiscal correspondiente.

---

## S3 — Calendario (bcalendar)

### T-012 · `bcalendar.cal_fiscal_year`

**Propósito:** Gestión de años fiscales con 12 períodos mensuales. Soporta multi-gestión (corriente + anteriores simultáneas). Crítico para facturación SIN y reportes NIC/IAS.

**¿Qué registra?** Año fiscal (entero), estado (OPEN/CLOSED/CLOSED_WITH_ADJUSTMENTS/ARCHIVED), fecha de inicio, 12 períodos JSONB con estado individual, si es la gestión corriente.

**¿Cuándo se alimenta?** BOS Saga al crear el tenant. El módulo de contabilidad crea la gestión del año siguiente antes del cierre.

**Relaciones:** `tenant_id` + `company_id` (opcional, para empresas subsidiarias del tenant)

**Procesos necesarios:**
- Job de cierre automático a fin de año (configurable: día/mes de cierre fiscal Bolivia = 31-12)
- Validación: solo UN año con `is_current=true` por (tenant, company)
- Los módulos contables validan `WHERE status='OPEN' AND is_current=true` antes de registrar transacciones

**Código:** El árbol de políticas D5/D6 (fiscal) consulta esta tabla para determinar si el período contable está abierto.

**¿Necesita interfaz en el frontend?** Sí — módulo de gestión fiscal, dashboard de cierre de año.

---

### T-014 · `bcalendar.cal_calendar`

**Propósito:** Colecciones de calendarios por tenant. Un calendario agrupa eventos, alarmas y horarios del mismo tipo (WORK, FISCAL, PROCESS, COMPLIANCE, HOLIDAY, MAINTENANCE).

**¿Qué registra?** Nombre, tipo, zona horaria IANA, color para UI, si es de sistema (no borrable).

**¿Cuándo se alimenta?** Bootstrap (calendarios de sistema predefinidos). Los administradores crean calendarios adicionales.

**Procesos necesarios:**
- Al crear tenant: seed de calendarios base (Calendario Laboral Bolivia, Calendario Fiscal, Calendario de Compliance)

**¿Necesita interfaz en el frontend?** Sí — vista de calendarios del tenant, selector de calendario.

---

### T-015 · `bcalendar.cal_event`

**Propósito:** Eventos maestros con soporte de recurrencia RFC 5545. Una fila = un evento o una serie recurrente completa. Las ocurrencias se expanden on-demand.

**¿Qué registra?** Título, fechas, regla de recurrencia (rrule TEXT RFC 5545), fechas excluidas (exdate[]), duración, estado (CONFIRMED/TENTATIVE/CANCELLED).

**¿Cuándo se alimenta?** Cuando un administrador o el sistema crea eventos (feriados, cierres, vencimientos).

**Código:** El evaluador D3 temporal del árbol de políticas consulta eventos para determinar si un acceso cae en un período controlado.

**¿Necesita interfaz en el frontend?** Sí — vista de calendario tipo Google Calendar.

---

### T-016 · `bcalendar.cal_alarm`

**Propósito:** Alarmas asociadas a eventos. Define cuándo y por qué canal bNotify envía la notificación.

**¿Qué registra?** `trigger_seconds` (negativo = antes del evento), canal (EMAIL/SMS/WHATSAPP/PUSH/CHAT/UI), template, receptor, próximo disparo.

**Procesos necesarios:**
- Job polling: `WHERE next_trigger_at <= NOW() AND is_active = true`
- Al disparar: insertar en `cal_notification_log` + llamar a bNotify via JSON-RPC

---

### T-017 · `bcalendar.cal_notification_log` 🔒 WORM

**Propósito:** Registro inmutable de notificaciones enviadas. Evidencia de que las alarmas se dispararon (compliance y auditoría).

**¿Cuándo se alimenta?** Automáticamente al disparar cada alarma. No tiene UPDATE/DELETE.

---

### T-018 · `bcalendar.cal_holiday`

**Propósito:** Feriados fijos y móviles por país/tenant. Bolivia tiene 26 feriados nacionales por ley + feriados departamentales. El evaluador D3 consulta esta tabla para horarios laborales reales.

**¿Qué registra?** Nombre del feriado, fecha, si es recurrente anual, país, región (departamento).

**¿Cuándo se alimenta?** Bootstrap (feriados nacionales Bolivia) + administrador de tenant para feriados propios.

**Procesos necesarios:**
- Job anual: cargar feriados móviles del año siguiente (Carnaval, Semana Santa cuyas fechas cambian cada año)

---

### T-019 · `bcalendar.cal_schedule`

**Propósito:** Horarios de trabajo y turnos por tenant. Define ventanas de acceso permitido. El evaluador D3 usa esto para validar si el acceso ocurre en horario laboral.

**¿Qué registra?** Días de la semana ({1=lun..7=dom}), hora de inicio/fin, turnos JSONB (mañana/tarde/noche), comportamiento fuera de horario (BLOCKED/PERMITTED/REQUIRES_APPROVAL).

**¿Cuándo se alimenta?** Al registrar el tenant (horario laboral estándar 8-18 Lun-Vie). Puede personalizarse para turnos especiales.

**Código:** El Motor de Identidad evalúa: `SELECT access_outside_schedule FROM cal_schedule WHERE tenant_id=$1 AND is_default=true`.

**¿Necesita interfaz en el frontend?** Sí — configurador de horarios y turnos.

---

### T-124 · `bcalendar.cal_overtime_policy` ⭐ NUEVA

**Propósito:** Políticas de horas extra. Define si el acceso fuera del horario normal requiere override, qué aprobaciones activa, y qué LoA mínimo exige el PDP.

**¿Qué registra?** Máximo de horas extra diarias/semanales, si requiere solicitud de override y aprobación gerencial, LoA requerido para el override, tiers a los que aplica.

**¿Cuándo se alimenta?** Al registrar el tenant o cuando Recursos Humanos configura la política.

**Relaciones:** `schedule_id` → `cal_schedule` (schedule base al que aplica la política)

**Código:** Cuando el PDP detecta acceso fuera de horario:
1. Consulta `cal_overtime_policy` del tenant/schedule
2. Si `requires_override_request=true` → redirige a flujo JIT (T-182)
3. Si `loa_required_for_override=2` → exige AAL2 antes de aprobar el override

---

### T-125 · `bcalendar.cal_break_policy` ⭐ NUEVA

**Propósito:** Políticas de pausa (almuerzo, descanso). Define si el sistema suspende sesiones activas durante el break y si el usuario debe re-autenticarse al volver.

**¿Qué registra?** Ventana de pausa (start/end TIME), si suspende sesiones, si permite reanudar, si re-autenticación es requerida, tiers a los que aplica.

**¿Cuándo se alimenta?** Al registrar el tenant. El horario de almuerzo (12:00-14:00) es el caso más común.

**Procesos necesarios:**
- Job al inicio del break: `UPDATE ses_session_log SET is_active=false WHERE user_id IN (usuarios del tenant en pausa) AND is_active=true` (si `suspend_active_sessions=true`)
- Evento CAEP: `session_revoked` para notificar al frontend via SSF

---

## S4 — Roles (bauth)

### T-040 · `bauth.idn_roles_rol_type` 🌱

**Propósito:** Catálogo cerrado de 10 tipos de cuenta. Permite que el sistema aplique políticas diferenciadas según si la identidad es humana (INDIVIDUAL), no-humana (BOT, DEVICE, SERVICE), de emergencia (EMERGENCY), etc.

**¿Qué registra?** Code único, nombre JSONB. Inmutable una vez creado (historicidad).

**¿Cuándo se alimenta?** Bootstrap. Los 10 tipos vienen en los SEEDs de la DDL. No se agregan tipos nuevos sin análisis de impacto en el PDP.

**Relaciones:**
- `idn_roles_rol_hierarchical.type_id` → FK
- El PDP aplica reglas distintas por tipo (ej: EMERGENCY siempre requiere quórum T-183)

**¿Necesita interfaz en el frontend?** Solo lectura — selector al crear un rol.

---

### T-042 · `bauth.idn_roles_rol_tier` 🌱

**Propósito:** Parámetros de seguridad por tier. 11 tiers con niveles de aseguramiento, timeouts de sesión, MFA obligatorio y límites de sesiones concurrentes distintos.

**¿Qué registra?** Por tier: LoA requerido (AAL1/2/3), session_timeout_minutes, max_sessions, step_up_loa, si MFA es obligatorio, métodos MFA permitidos.

**¿Cuándo se alimenta?** Bootstrap. Los 11 tiers vienen en los SEEDs. SU requiere LoA3+MFA con solo 1 sesión concurrente. VISITANTE requiere LoA1 con 30 minutos de timeout.

**Código:** Al emitir el JWT, el Motor de Identidad consulta el tier del rol activo para establecer el `exp` (expiración) del token.

---

### T-041 · `bauth.idn_roles_rol_hierarchical`

**Propósito:** Árbol de roles por tenant (adjacency list). Es el catálogo de roles empresariales: 368 roles en 7 tiers, 66 plantillas base, 21 sectores CAEB. Complementado por T-063 (closure table) para herencia DAG-OR eficiente.

**¿Qué registra?** Rol con su tier, tipo, código único por tenant, nombre JSONB, profundidad, estado (ACTIVE/INACTIVE/DEPRECATED/ARCHIVED/SUSPENDED/IN_REVIEW), sector CAEB, versión, referencia a nodo en el árbol de políticas (template_id).

**B02 — Vigencia y ciclo de vida del rol (`[B02 §validity_period]` del contrato RolTemplate):**

| Columna B02 | Tipo | Semántica |
|---|---|---|
| `validity_type` | `role_validity_type NOT NULL DEFAULT 'INDEFINITE'` | Tipo de vigencia: `INDEFINITE` (sin fin) / `FIXED` (fecha fin fija) / `PROJECT_BASED` (fin por hito, humano decide) / `TEMPORARY` (fin = `valid_from + duration_interval`, no extensible) / `EMERGENCY` (fin = `created_at + 72h`, NIST AC-2(2)). |
| `valid_from` | `DATE NOT NULL DEFAULT CURRENT_DATE` | Inicio de vigencia del rol. |
| `valid_until` | `DATE` | Fecha de expiración. Para `FIXED`: obligatorio (humano la fija). Para `TEMPORARY/EMERGENCY`: calculado por trigger `trg_irrh_b02_validity`; prohibido pasar manual. |
| `duration_interval` | `INTERVAL` | Duración para tipos `TEMPORARY` y `EMERGENCY`. El trigger calcula `valid_until = valid_from + duration_interval`. |
| `max_renewals` | `SMALLINT` | Límite de renovaciones (`NULL` = sin límite). Control anti privilege-creep (PCI DSS 7.2.4). |
| `renewal_count` | `SMALLINT NOT NULL DEFAULT 0` | Contador de renovaciones ejecutadas. |

**Constraint `chk_irrh_b02_validity`:** FIXED requiere `valid_until`; TEMPORARY/EMERGENCY requieren `duration_interval` y prohíben `valid_until` directo; INDEFINITE/PROJECT_BASED: sin restricción adicional.

**Trigger `trg_irrh_b02_validity`:** BEFORE INSERT OR UPDATE. Calcula `valid_until` para TEMPORARY/EMERGENCY. Si `valid_until <= NOW()` y `status = 'ACTIVE'`: cambia estado a `DEPRECATED` e inserta evento en `idn_roles_rol_lifecycle_event` con `trigger_type = 'AUTO_EXPIRY'`.

**ENUM `rol_status_enum`:** ahora incluye 6 valores: `ACTIVE / INACTIVE / DEPRECATED / ARCHIVED / SUSPENDED / IN_REVIEW`. El estado `IN_REVIEW` es para campañas IGA access review (ver T-194).

**¿Cuándo se alimenta?** Al registrar el tenant, BOS Saga crea los roles base según el sector CAEB del cliente. El administrador crea roles adicionales.

**Relaciones:**
- `parent_id` → auto-referencia (nodo padre en la jerarquía)
- `type_id` → T-040 (tipo de cuenta)
- `template_id` → T-162 (nodo DOMAIN del árbol de políticas) — DEFERRABLE INITIALLY DEFERRED
- `idn_roles_rol_closure` → closure table de herencia

**¿Necesita interfaz en el frontend?** Sí — visor del árbol de roles con drag-and-drop. Es una de las interfaces más complejas del dashboard bAuth.

---

### T-063 · `bauth.idn_roles_rol_closure`

**Propósito:** Closure table del DAG de herencia de roles (OR-inheritance: un rol hereda los privilegios de TODOS sus ancestros). Permite consultas O(1) de ancestros y descendientes.

**¿Qué registra?** Tripleta (ancestor_id, descendant_id, depth). depth=0 = rol es ancestro de sí mismo. depth=1 = hijo directo. depth=N = N niveles de herencia transitiva.

**¿Cuándo se alimenta?** Por triggers en idn_roles_rol_hierarchical al insertar o cambiar parent_id. Nunca manualmente.

**Procesos necesarios:**
- Trigger `trg_irrh_closure_insert`: al insertar un rol, inserta las tripletas de reflexividad + herencia transitiva
- Trigger `trg_irrh_closure_update_parent`: al cambiar parent_id, recalcula toda la subárbol

**Código:** El PrivilegeEngine usa esta tabla para compilar el BitmaskBundle:

```sql
-- Todos los roles heredados por un usuario via DAG-OR
SELECT rc.ancestor_id
FROM idn_roles_rol_closure rc
WHERE rc.descendant_id = $user_role_id
  AND EXISTS (
    SELECT 1 FROM idn_roles_rol_hierarchical r
    WHERE r.id = rc.ancestor_id AND r.is_inheritable = true AND r.status = 'ACTIVE'
  );
```

**¿Necesita interfaz en el frontend?** No — solo la lógica interna del PrivilegeEngine la accede directamente.

---

### T-161b · `bauth.idn_policy_node_type` 🌱

**Propósito:** Catálogo de tipos de nodo del árbol de políticas (`idn_roles_template.tipo`). Fuente única de verdad para presentación visual (color de badge, tipografía, abreviatura) y descripción bilingüe. Reemplaza el `CHECK chk_irt_tipo` — `tipo` es FK textual a este catálogo.

**¿Qué registra?** Por tipo canónico de nodo: `codigo` (PK textual, ej: `dominio`, `bloque`, `evaluacion`, `atomo`), `abbreviation`, `nombre_es/en`, `descripcion_es/en`, paleta de badge (`color_key`), paleta de texto valor (`color_key_valor`), peso tipográfico (`font_weight`: 400/500/600/700), token de tamaño (`font_size_token`: xs/sm/base/md), si usa fuente monoespaciada, `show_badge`, `expanded_default`.

**Uso en Flutter:** El cliente carga este catálogo al inicializar (`BauthApi.cargarCatalogoTipos()`) y renderiza cada nodo del árbol sin ningún switch de presentación hardcodeado. Cambiar el tema del dashboard adapta colores sin tocar código Dart.

**Nota:** El tipo virtual `diagnostico` (linter Dart) **no** aparece en esta tabla — se inyecta solo por el cliente como fallback de error.

**¿Cuándo se alimenta?** Bootstrap (seed de tipos canónicos). Solo el administrador SBOS agrega tipos nuevos.

---

### T-194 · `bauth.idn_roles_iga_category` 🌱

**Propósito:** Categorías de gobernanza IGA para el ciclo de vida de roles. Determina la frecuencia de certificación de acceso (`review_cycle_days`) y si el rol requiere campaña de revisión PAM trimestral (`is_privileged`). 7 categorías inmutables post-seed.

**¿Qué registra?** Por categoría: `code` (UNIQUE), nombre JSONB, `is_privileged`, `review_cycle_days`:

| Código | `is_privileged` | `review_cycle_days` |
|---|---|---|
| `BUSINESS` | false | 365 |
| `IT_INFRASTRUCTURE` | true | 90 |
| `APPLICATION` | false | 365 |
| `PRIVILEGED` | true | 90 |
| `EMERGENCY` | true | 30 |
| `SERVICE` | false | 365 |
| `STANDARD` | false | 365 |

**Procesos:** El job de access review consulta esta tabla para determinar frecuencia y si generar campaña PAM. `is_privileged=true` → revisión trimestral obligatoria (NIST AC-2(7)).

**Normas:** IGA best practices · NIST SP 800-53 AC-2(7) · ISO 24760-2:2025.

**¿Necesita interfaz en el frontend?** Solo lectura — selector al configurar el `iga_category` de un rol.

---

### T-B02L · `bauth.idn_roles_rol_lifecycle_event` 🔒 WORM

**Propósito:** Log WORM append-only de cada transición de estado del rol. Registro forense inmutable del ciclo de vida (B02 `§lifecycle`). Equivalente a T-160 para NHI. REVOKE UPDATE/DELETE desde PUBLIC y `bauth_app_role`.

**¿Qué registra?** Por evento: `role_id` (FK a T-041), estados `from_status / to_status`, `trigger_type` (canal que originó la transición), `actor_id` (UUID del actor humano o `NULL` si automático), `reason` (texto libre), `validity_snapshot` (JSONB con `validity_type/valid_from/valid_until/duration_interval` al momento del evento), `ctx_id` (SBOS-049 obligatorio), `occurred_at`, `prev_hash` + `entry_hash` (cadena SHA256 — **bauth_44 ✅ aplicado VPS 2026-07-25**).

**`trigger_type` posibles:**

| Valor | Cuándo |
|---|---|
| `MANUAL` | Administrador cambia estado vía dashboard o RPC |
| `AUTO_EXPIRY` | Trigger `trg_irrh_b02_validity` detecta `valid_until <= NOW()` |
| `RECONCILE` | Loop de reconciliación detecta drift |
| `IGA_REVIEW` | Campaña de access review IGA (T-194) |
| `BREAKGLASS` | Activación de emergencia |
| `BOOTSTRAP` | Inicialización del sistema |

**Índices:** `(role_id, occurred_at DESC)` para historial por rol · `(to_status, occurred_at DESC)` para dashboard de transiciones · `(occurred_at DESC) WHERE trigger_type = 'AUTO_EXPIRY'` para monitor de expiraciones.

**¿Cuándo se alimenta?** Por trigger `trg_irrh_b02_validity` en T-041 (AUTO_EXPIRY) y por el daemon en transiciones manuales. Nunca UPDATE o DELETE.

**Normas:** ISO 27001 A.8.15 (audit log inmutable) · NIST AC-2(2) (acceso de emergencia temporal) · PCI DSS Req 10.2 (eventos de cambio de acceso).

**¿Necesita interfaz en el frontend?** Sí — timeline de transiciones por rol en el panel de detalle de rol.

---

## S5 — Versionado (bauth)

> Motor de Versionado Universal (MVU 1.13) — cuatro tablas que gobiernan el ciclo de vida de las definiciones de rol (T-041). Trabajan en conjunto: T-152 responde "¿cómo era?", T-153 gestiona "¿qué se propone?", T-154 define "¿hasta cuándo se guarda?", T-155 registra "¿qué cambió en el contrato?".

### T-152 · `bauth.idn_roles_ver_b01_audit_log` 🔒 WORM

**Propósito:** Historia WORM de versiones **cerradas** de `idn_roles_rol_hierarchical` (T-041). Responde "¿cómo era el rol X el día Y?" con as-of temporal en segundos. Implementa `[B01 §audit.change_history[]]` del contrato RolTemplate.

**¿Qué registra?** Por versión cerrada: snapshot JSONB completo del rol (`snapshot`), bloques normados afectados (`blocks_touched`), normas vigentes (`standard_ref`), delta de campos (`fields_changed`), tipo de cambio semántico (`MAJOR/MINOR/PATCH`), canal de cambio, actor y aprobador. `is_anchor=true` en cambios MAJOR (fotografía completa — requerida por constraint).

**Diseño temporal (PG18):** `UNIQUE (entity_id, sys_period WITHOUT OVERLAPS)` con `btree_gist` — garantía de no-solapamiento por motor de BD. `chk_irvb01al_closed` impide rangos abiertos (`upper_inf`). La versión vigente vive en T-041; aquí solo entran versiones cerradas.

**Hash-chain:** `prev_hash + entry_hash` con REVOKE UPDATE/DELETE. Trigger `trg_irvb01al_worm` — función `fn_irvb01al_worm_hash()` — **aplicado en VPS 2026-07-25** (bauth_44 ✅). Cada INSERT calcula `entry_hash = SHA256(id||entity_id||sys_period||snapshot||blocks_touched||change_type||ctx_id||prev_hash)` y encadena con el hash de la última fila por `upper(sys_period) DESC`. Índices: `gist(sys_period)` para as-of, `gin(blocks_touched)` y `gin(standard_ref)` para auditorías por bloque/norma.

**¿Cuándo se alimenta?** Por trigger en T-041 al cerrar una versión. Nunca directamente. El trigger `trg_irvb01al_worm` firma cada fila con SHA256 antes de insertarla.

**¿Necesita interfaz en el frontend?** Sí — timeline "historial de versiones" del rol con diff entre versiones (`fields_changed`).

---

### T-153 · `bauth.idn_roles_ver_b03_approval_queue`

**Propósito:** Cola de cambios MAJOR pendientes de quórum N-de-M sobre T-041. Implementa `[B03 §approval_workflow]`: ningún cambio MAJOR se aplica directamente — espera aquí hasta alcanzar quórum. La versión vigente sigue rigiendo durante `status=PENDING`.

**¿Qué registra?** Estado propuesto completo (`proposed_state` JSONB), bloques normados afectados, impacto de seguridad, lista de roles aprobadores requeridos (`approver_roles[]`), aprobaciones recibidas (`approvals` JSONB array), deadline SLA, si fue escalado, estado (`PENDING/APPROVED/REJECTED/EXPIRED`) y resolución con nota.

**Dual control (NIST AC-5):** Constraint `chk_irvb03aq_dual_ctrl` prohíbe `resolved_by = proposed_by` — quien propone no puede aprobar. `required_approvers >= 1` y `<= cardinality(approver_roles)`.

**Flujo:** propuesta → `PENDING` (SLA activo) → quórum alcanzado → `APPROVED` → el sistema aplica el cambio en T-041 y registra en T-152. Si vence el SLA sin quórum: `escalated=true` → alertar a supervisor.

**¿Necesita interfaz en el frontend?** Sí — panel de propuestas con bandeja de aprobación para roles T1/T0.

---

### T-154 · `bauth.idn_roles_ver_b01_retention_policy`

**Propósito:** Política de retención legal por entidad gobernada (clasificación C1). Define cuánto tiempo se mantiene el historial vivo (`hot_window`), cómo se compacta al archivar (`KEEP_ALL/KEEP_ANCHORS/KEEP_LAST_N`), y el piso legal irrenunciable (≥365 días — D99). `legal_hold=true` suspende toda purga ante litigio.

**¿Qué registra?** Una fila por entidad gobernada: `entity_name` (UNIQUE), `info_class` (`C1`–`C4`), `hot_window` (historia viva sin compactar), `compaction_policy`, `retention_total` con constraint `chk_irvb01rp_piso_d99 CHECK (retention_total >= INTERVAL '365 days')`, `legal_basis`, referencias normativas.

**Seed incluido:** `idn_roles_rol_hierarchical` → 10 años (Ley 843 Bolivia Art. 44 · PCI DSS Req 10.5 · AU-11 · SOX-404 · A.5.33).

**¿Cuándo se alimenta?** Bootstrap (seed automático). El administrador de cumplimiento agrega entidades adicionales.

**¿Necesita interfaz en el frontend?** Sí — panel de gobernanza de retención (solo T0/SU).

---

### T-155 · `bauth.idn_roles_ver_contract_revision_log`

**Propósito:** Changelog estructural del contrato RolTemplate entre versiones (ej: v5.0→v6.0). No es una copia del contrato — es el delta estructural: qué bloques cambiaron, qué campos entraron/salieron, si el cambio es `COMPATIBLE` o `BREAKING`, y qué migración DDL lo materializó. Append-only histórico.

**¿Qué registra?** Transición UNIQUE `(contract_name, version_from, version_to)`: bloques afectados (`blocks_changed[]`), campos agregados/eliminados/modificados, normas afectadas (`standards_affected[]`), compatibilidad, referencia a migración DDL, razón y aprobador.

**¿Cuándo se alimenta?** Al cerrar cada ciclo de versionado del contrato (publicación de nueva versión de RolTemplate). El `chk_irvcrl_diff_ver` prohíbe `version_to = version_from`.

**¿Necesita interfaz en el frontend?** Solo lectura — log histórico de evolución del contrato para auditores y documentadores.

---

## S6 — Árbol de Políticas (bauth)

### T-174 · `bauth.privilege_verb`

**Propósito:** Catálogo de verbos atómicos del sistema. Un verbo = una acción elemental controlada por el PDP (READ, WRITE, DELETE, APPROVE, SIGN, EXPORT, AUDIT_VIEW, ADMIN_CONFIG).

**¿Qué registra?** `code` único, nombre JSONB, estado de activación. Los verbos nunca se eliminan — se desactivan para mantener trazabilidad histórica.

**¿Cuándo se alimenta?** Bootstrap. Los verbos base vienen de la especificación de dominios D01..D37.

**¿Necesita interfaz en el frontend?** Solo lectura — visible al configurar átomos en el árbol.

---

### T-175 · `bauth.privilege_verb_conflict`

**Propósito:** Matriz SoD (Separation of Duties). Define pares de verbos que no pueden coexistir en el mismo usuario. Garantiza separación de funciones NIST AC-5 / ISO 27001 A.6.1.2.

**¿Qué registra?** Par (verb_a_id, verb_b_id) con tipo de conflicto:
- `SOD_ESTATICO`: prohibición permanente (ej: APPROVE + SIGN del mismo documento)
- `SOD_DINAMICO`: prohibición solo si ambos activos en la misma sesión (ej: AUDIT_VIEW + DELETE)
- `AFINIDAD`: los verbos se complementan (requerimiento conjunto, no conflicto)

La constraint `chk_pvc_order (verb_a_id < verb_b_id)` elimina duplicados (A,B) = (B,A).

**Procesos necesarios:**
- El PDP consulta esta tabla al compilar el BitmaskBundle para detectar conflictos SoD antes de emitir el JWT
- Las excepciones SoD aprobadas viven en `privilege_exception_record` (T-179)

---

### T-162 · `bauth.idn_roles_template` ⚡ TRIGGER

**Propósito:** El árbol de políticas compartido del sistema bAuth. UN solo árbol (sin tenant_id). Es el PAP (Policy Administration Point) del XACML 3.0: define qué permisos existen, cómo se estructuran, y qué condiciones AtomLang los rigen.

**¿Qué registra?** Nodos del árbol jerárquico DOMAIN > BLOCK > POLICY > MODULE > EVALUATION > ATOM/OBLIGATION:
- `DOMAIN`: raíz de un dominio de control (D01..D37). Tiene `domain_number`.
- `BLOCK`: agrupación dentro del dominio (B1, B2, etc.)
- `POLICY`: política específica (P-AUTH-001)
- `MODULE`: módulo funcional dentro de una política
- `EVALUATION`: átomo evaluable. **Solo estos nodos tienen `atom_position`** (posición de bit en el BitMask 64-bit)
- `ATOM`: sub-átomo de un EVALUATION
- `OBLIGATION`: acción obligatoria al aplicar el efecto

**El trigger `trg_irt_atom_position`** asigna automáticamente `atom_position` desde `roles_atom_position_seq` a cada nodo EVALUATION en INSERT. La posición es inmutable una vez asignada.

**¿Qué es `atom_position`?** Es la posición del bit en el BitMask 64-bit del dominio correspondiente. El PrivilegeEngine compila el BitmaskBundle: para cada usuario, hace OR de los atom_position de todos los EVALUATION que tiene PERMIT → resultado es un int64 por dominio. Evaluación: `bitmask & (1 << atom_position) != 0` → en < 0.5ns.

**¿Cuándo se alimenta?** Por el PAP (administrador de políticas SBOS) mediante propuestas con quórum (T-189). Nunca directamente.

**`condition_expr`:** JSON AST de la condición AtomLang compilada. Ejemplo: `{"op":"AND","left":{"ref":"@current_time","op":"BETWEEN","range":["08:00","18:00"]},"right":{"ref":"@tenant.status","op":"EQ","val":"ACTIVE"}}`.

**`path`:** Camino materializado único: `D01.B1.P001.E001`. Permite lookup directo O(1).

**¿Necesita interfaz en el frontend?** Sí — visor del árbol de políticas (solo lectura para BIZ_N1+, edición para T0/SU con quórum).

---

### T-163 · `bauth.idn_roles_template_history` 🔒 WORM

**Propósito:** Registro WORM inmutable de cambios al árbol de políticas T-162. Todo INSERT, UPDATE o DEACTIVATE en T-162 queda aquí con hash-chain SHA-256. Convención uniforme con `privilege_atom_audit` (T-170b).

**¿Cuándo se alimenta?** Por trigger en `idn_roles_template`. REVOKE UPDATE/DELETE desde PUBLIC y `bauth_app_role` — solo INSERT desde el daemon.

**Columnas WORM:** `before_row JSONB` / `after_row JSONB` (convención uniforme — no `old_data/new_data`). `prev_hash BYTEA NULL` (primer evento = NULL). `hash_chain BYTEA NOT NULL`.

**Código hash-chain:** `SHA-256(prev_hash || node_id || operation || after_row::text || created_at)`. Permite detectar eliminación o alteración de registros de auditoría.

---

## S7 — Identidad D00 (bauth)

### T-156 · `bauth.idn_identity_entity`

**Propósito:** Raíz del modelo D00 de identidad. Toda identidad en SBOS es una entidad aquí. La jerarquía de 5 niveles modela la estructura organizacional de cualquier empresa boliviana.

**¿Qué registra?** Entidad con su nivel (tenant/bdomain/bsubdomain/pos/actor), código único por tenant, nombre JSONB, profundidad en el árbol, path materializado, IAL mínimo requerido.

**Jerarquía D00:**
- `tenant`: el tenant SBOS (ej: "skull")
- `bdomain`: empresa subsidiaria (ej: "skull-corp")
- `bsubdomain`: sucursal o división (ej: "skull-corp-la-paz")
- `pos`: punto de venta o unidad operativa (ej: "pos-01")
- `actor`: identidad humana o NHI que porta credenciales

**¿Cuándo se alimenta?** BOS Saga al registrar el tenant (crea el nodo tenant). El administrador crea empresas, sucursales, puntos y actores.

**Código:** `user_id` en todas las demás tablas de bauth es el `entity_id` de un nodo tipo `actor` en esta tabla.

**¿Necesita interfaz en el frontend?** Sí — árbol organizacional con gestión de entidades. Vista más importante del módulo IAM.

---

### T-157 · `bauth.idn_identity_attribute`

**Propósito:** Atributos de identidad por entidad. Modelo EAV controlado (namespace.key=value). Permite almacenar atributos verificables (cédula de identidad, NIT, biometría) y no verificables (preferencias), con niveles IAL distintos.

**¿Qué registra?** Namespace + clave + valor JSONB + si está verificado + fuente de verificación + vigencia.

**Namespaces:**
- `core`: nombre, CI, fecha de nacimiento
- `professional`: cargo, empresa, sector
- `verification`: documentos IAL2/3
- `security`: dispositivos MFA, IPs de confianza
- `contact`: email, teléfono, dirección
- `fiscal`: NIT, actividad económica CAEB

**Procesos necesarios:**
- Al actualizar un atributo: crear nueva fila con nueva vigencia (no UPDATE del valor)
- IAL2/IAL3: el proceso de verificación marca `verified=true` + `verified_by` + evidencia

**¿Necesita interfaz en el frontend?** Sí — perfil de identidad del actor con secciones por namespace.

---

### T-158 · `bauth.idn_identity_attribute_history` ✅ IMPLEMENTADA (v2.5.0)

**Bloque:** D00-B05 `atributos` · **Nivel DDL:** NIVEL 7 (después de T-157) · **Particionada RANGE (changed_at)**

**Propósito:** Registro WORM (Write Once Read Many) de todos los cambios en `idn_identity_attribute` (T-157). Append-only particionado por mes, con hash-chain SHA-256 por cadena `(entidad_id, attr_namespace, attr_key)`. Garantiza integridad forense: ningún cambio de atributo puede borrarse ni modificarse retroactivamente.

**Normas que cumple:**
- ISO 27001:2022 A.8.15 — logging de operaciones sobre datos de identidad
- NIST SP 800-53 Rev.5 AU-9/AU-10 — integridad y no-repudio de registros de auditoría
- PCI DSS 4.0 Req. 10.3.2 — protección de logs contra borrado/modificación
- GDPR Art. 30 — registro de actividades de tratamiento de datos personales
- GAP-04 (bAuth interno) — hash-chain WORM como mecanismo de no-repudio

**Estructura de la tabla:**

| Columna | Tipo | Restricción | Descripción |
|---|---|---|---|
| `history_id` | UUID | PK (con changed_at) | UUIDv7 — orden cronológico garantizado |
| `attribute_id` | UUID | FK RESTRICT → T-157 | No borrar atributo con historial |
| `entity_id` | UUID | NOT NULL | Denorm. de T-157 para auditoría por entidad |
| `attr_namespace` | TEXT | NOT NULL | Espacio del atributo (core, security, etc.) |
| `attr_key` | TEXT | NOT NULL | Clave del atributo |
| `attr_value_old` | JSONB | NULL | Valor anterior (NULL en INSERT) |
| `attr_value_new` | JSONB | NOT NULL | Valor nuevo |
| `changed_by` | UUID | FK RESTRICT → T-156 | Entidad que realizó el cambio |
| `change_reason` | TEXT | NULL | Justificación del cambio |
| `operation` | TEXT | CHECK | `INSERT` \| `UPDATE` \| `SOFT_DELETE` |
| `prev_hash` | TEXT | NULL | Hash fila anterior de la cadena (NULL = primera) |
| `row_hash` | TEXT | NOT NULL | SHA-256 de la cadena completa (GAP-04) |
| `ctx_id` | TEXT | NOT NULL | Context Plane SBOS-049 |
| `changed_at` | TIMESTAMPTZ | NOT NULL PK | Clave de partición |

**PK compuesta:** `(history_id, changed_at)` — requerida por PostgreSQL para tablas particionadas.

**Fórmula hash-chain (GAP-04):**
```
row_hash = SHA-256(
    history_id || atributo_id || attr_key ||
    attr_value_new::text || changed_at::text ||
    COALESCE(prev_hash, '')
)
```

**Particiones (RANGE changed_at):**

| Partición | Rango |
|---|---|
| `idn_identity_attribute_history_2026_07` | 2026-07-01 → 2026-08-01 |
| `idn_identity_attribute_history_2026_08` | 2026-08-01 → 2026-09-01 |
| `idn_identity_attribute_history_2026_09` | 2026-09-01 → 2026-10-01 |
| `idn_identity_attribute_history_2026_10` | 2026-10-01 → 2026-11-01 |
| `idn_identity_attribute_history_2026_11` | 2026-11-01 → 2026-12-01 |
| `idn_identity_attribute_history_2026_12` | 2026-12-01 → 2027-01-01 |

> Nueva partición mensual se crea mediante `CREATE TABLE … PARTITION OF` antes del primer día de cada mes.

**Índices:**

| Nombre | Columnas | Uso |
|---|---|---|
| `idn_identity_attribute_history_pkey` | `(history_id, changed_at)` | PK requerida |
| `idx_iah_atributo_id` | `(atributo_id, changed_at)` | Historial completo de un atributo |
| `idx_iah_entidad_ns_key` | `(entidad_id, attr_namespace, attr_key, changed_at)` | Cadena WORM por entidad+atributo |
| `idx_iah_changed_by` | `(changed_by, changed_at)` | Auditoría por actor |
| `idx_iah_ctx_id` | `(ctx_id, changed_at)` | Trazabilidad Context Plane |

**Seguridad WORM:**
```sql
REVOKE UPDATE, DELETE ON bauth.idn_identity_attribute_history FROM bauth_app_role;
```

**¿Necesita semilla (seed)?** No — es una tabla de auditoría; se llena por triggers al operar T-157.

**¿Necesita interfaz en el frontend?** Vista de solo lectura en panel de auditoría de identidad.

---

### T-159 · `bauth.idn_identity_requirement` ✅ IMPLEMENTADA (v2.4.0)

**Bloque:** D00-B03 `usuario_esquema` · **Nivel DDL:** NIVEL 6 (después de T-157)

**Propósito:** Define el MOLDE formal de completitud del usuario: qué atributos son obligatorios por combinación `(entity_type, ial_level)`. Sin esta tabla, el Motor de Identidad no puede validar que un actor cumple el esquema IAL requerido antes de elevar su nivel de aseguramiento.

**¿Qué registra?** Por cada combinación de tipo de entidad + nivel IAL:
- `attr_namespace` + `attr_key`: el atributo requerido en `idn_identity_attribute`
- `is_required`: si el atributo es obligatorio
- `must_be_verified`: si `idn_identity_attribute.verified = true` es obligatorio
- `accepted_sources`: fuentes de verificación válidas (`self`, `document`, `government`, `biometric`, `employer`, `blockchain`)
- `validation_regex`: regex de validación del valor (ej: CI boliviana `^\d{7,8}$`)
- `max_age_days`: antigüedad máxima del atributo para considerarlo vigente (NULL = sin límite)
- `error_message JSONB`: mensaje bilingüe `{es, en}` devuelto al frontend

**Scope:** `tenant_id = NULL` = requisito global del sistema (aplica a todos los tenants). `tenant_id NOT NULL` = override del tenant (sobreescribe el global para esa clave). La resolución es: tenant override > global.

**¿Cuándo se alimenta?** Seeds en el DDL (requisitos base IAL1/IAL2/IAL3 para Bolivia). Los tenants pueden agregar requisitos adicionales vía `bauth.identity.schema.configure`.

**Seeds incluidos:**

| IAL | Namespace | Atributo | Verified | Fuentes |
|-----|-----------|----------|----------|---------|
| IAL1 | core | full_name | No | self |
| IAL1 | contact | email | No | self |
| IAL2 | core | full_name | Sí | document, government |
| IAL2 | core | national_id | Sí | document, government |
| IAL2 | contact | email | Sí | self, employer |
| IAL3 | core | full_name | Sí | government |
| IAL3 | core | national_id | Sí | government |
| IAL3 | verification | biometric_ref | Sí | biometric |

**Relaciones:**
- `tenant_id` → `idn_tenant(tenant_id)` (CASCADE DELETE)
- Referenciada por el Motor de Identidad al evaluar `pip_check_ial_completeness(entidad_id, ial_target)`

**Procesos necesarios:**
- Motor de Identidad (D00): `pip_check_ial_completeness(entidad_id, target_ial)` → consulta esta tabla, verifica contra T-157, devuelve lista de atributos faltantes o vacía si OK
- Al crear atributo IAL2/IAL3: verificar `accepted_sources` antes de marcar `verified=true`

**Nunca eliminar filas:** desactivar con `is_active = false` para mantener historicidad. La resolución del Motor de Identidad filtra `WHERE is_active = true`.

**¿Necesita interfaz en el frontend?** Sí — panel de administración "Esquema de identidad" visible para administradores del tenant (T0/T1). Permite agregar requisitos adicionales sin modificar el DDL.

**Normas:** NIST SP 800-63A-4 §4 · ISO/IEC 24760-2:2025 §5 · ISO 11179-3:2023

---

### ⚠️ `bauth.idn_identidad_dominio` *(SIN T-CODE — AUSENTE DEL DDL)*

**Estado:** el DomainRegistry (tabla que mapea entidades a dominios D01..D37) no tiene T-code asignado ni `CREATE TABLE` en el DDL. Es un gap de diseño.

**Propósito planeado:** registrar en qué dominios del árbol de políticas tiene membresía cada entidad. El PrivilegeEngine filtraría el BitmaskBundle al compilar: solo considera dominios donde la entidad tiene membresía activa.

---

### T-159 · `bauth.idn_roles_nhi_identity`

**Propósito:** Entidad raíz de toda identidad máquina gobernada del ecosistema SBOS. Registra daemons, pipelines, service accounts, bots, AI agents y workloads que necesitan credenciales. Cada NHI tiene un propietario humano accountable (`owner_id`) — quien rinde cuentas si el NHI actúa incorrectamente.

**¿Qué registra?** Tipo (`SERVICE_ACCOUNT/WORKLOAD/AGENT/BOT/API_CLIENT/CI_CD_PIPELINE`), propietario humano y respaldo (`backup_owner_id`), referencia única del NHI en el tenant (`system_ref`, ej: `bkernel:sync-worker-01`), `last_used_at` (detecta dormancia >90 días), `review_at` (cadencia: 30d CI/CD; 90d service accounts), estado (`ACTIVE/DORMANT/DECOMMISSIONED/SUSPENDED`).

**¿Cuándo se alimenta?** Al registrar un nuevo daemon o integración. Seeds IAM Installer: una fila por daemon SBOS (bkernel, biedata, bnotify, bsearch, bnexus).

**Relaciones:**
- `idn_roles_nhi_lifecycle_event` (T-160) → log WORM de ciclo de vida
- `idn_roles_nhi_certification` (T-161) → certificaciones mensuales
- `idn_roles_nhi_agent_identity` (T-190) → especialización para AI agents (1:1)

**Procesos necesarios:**
- Job de dormancia: `WHERE last_used_at < NOW() - INTERVAL '90 days' AND status='ACTIVE'` → alertar y marcar `DORMANT`
- Job de revisión: `WHERE review_at <= NOW() AND status='ACTIVE'` → crear certificación en T-161

---

### T-160 · `bauth.idn_roles_nhi_lifecycle_event` 🔒 WORM

**Propósito:** Log WORM append-only del ciclo de vida de cada NHI. Registro forense inmutable de cada transición de estado. REVOKE UPDATE/DELETE desde `bauth_app_role`.

**Eventos posibles:** `PROVISIONED → CERTIFIED → ROTATED / SUSPENDED → REACTIVATED → DECOMMISSIONED`, más `OWNER_CHANGED` y `REVIEW_SCHEDULED`.

**¿Cuándo se alimenta?** Por trigger en `idn_roles_nhi_identity` al cambiar `status`. Solo INSERT desde el daemon.

---

### T-161 · `bauth.idn_roles_nhi_certification`

**Propósito:** Certificaciones periódicas mensuales de NHI por el propietario técnico (más frecuente que certificación humana trimestral — NHI cambian más rápido). Obligatorio según NIST AC-2(7).

**¿Qué registra?** Período de revisión (`period_start/end`), `last_used_at` y `access_count` del período (señales clave — `access_count=0` es el indicador más fuerte para descomisionar), decisión (`CERTIFY/DECOMMISSION/REDUCE_SCOPE/ESCALATE`), justificación y revisor.

---

### T-190 · `bauth.idn_roles_nhi_agent_identity`

**Propósito:** Especialización de `idn_roles_nhi_identity` para agentes IA autónomos. Limita los dominios que puede usar el agente — `max_permission_scope[]` actúa como techo aunque el NHI padre tenga más acceso. Registra el árbol de orquestación (`orchestrator_id` auto-referencia) para forensia de cadenas de agentes.

**¿Qué registra?** Framework del agente (`agent_framework`), orquestador padre (`orchestrator_id`), dominios máximos (`max_permission_scope TEXT[]`), tipo de sesión (`EPHEMERAL/PERSISTENT`), si puede lanzar sub-agentes (`can_spawn_agents`), profundidad máxima de delegación (`max_spawn_depth`).

**Constraint de coherencia:** `chk_iai_spawn` garantiza: `can_spawn_agents=false → max_spawn_depth=0` (y viceversa). `can_spawn_agents=false` por defecto — solo orquestradores explícitamente aprobados pueden crear sub-agentes.

**⚠️ PENDIENTE HITL:** herencia de permisos padre→hijo vs permisos propios independientes.

**Normas:** NIST AI RMF 1.0 · CSA NHI Governance 2025 · ISO 42001:2023.

**¿Necesita interfaz en el frontend?** Sí — subpanel dentro del inventario NHI para agentes IA, con árbol de orquestación visualizado.

---

### T-165 · `bauth.idn_identity_proofing` ✅ IMPLEMENTADA (v2.6.0)

**Bloque:** D00-B06 `proofing` · **Nivel DDL:** NIVEL 6 (después de T-159)

**Propósito:** Proceso de identity proofing por usuario individual. Registra el IAL efectivamente alcanzado, tipo de proceso, evidencias recopiladas (FAIR/STRONG/SUPERIOR según NIST), revisor, estado y fechas de vencimiento y re-proofing.

**Normas:** NIST SP 800-63A-4 §4–6 · ISO/IEC 29115:2013 · ISO 24760-2:2025 §7.2 · eIDAS 2.0 Art. 24

| Columna | Tipo | Descripción |
|---|---|---|
| `proofing_id` | UUID PK | UUIDv7 |
| `entity_id` | UUID FK CASCADE | Actor sujeto del proofing |
| `tenant_id` | UUID FK CASCADE | Tenant que ejecuta el proofing |
| `ial_achieved` | ial_level_enum | IAL efectivamente alcanzado |
| `proofing_type` | TEXT CHECK | SELF_ASSERTED · REMOTE_UNATTENDED · REMOTE_ATTENDED · IN_PERSON · TRUSTED_REFEREE |
| `evidence` | JSONB | Estructura `{FAIR:[...], STRONG:[...], SUPERIOR:[...]}` |
| `evidence_count` | SMALLINT GENERATED | Suma de evidencias (columna computada) |
| `reviewer_id` | UUID FK NULL | Obligatorio para IAL3 (IN_PERSON/TRUSTED_REFEREE) |
| `status` | TEXT CHECK | PENDING · IN_PROGRESS · PASSED · FAILED · EXPIRED |
| `expires_at` | TIMESTAMPTZ NULL | IAL2: 365d · IAL3: 180-730d |
| `reproofing_at` | TIMESTAMPTZ NULL | Job: notificar via bNotify cuando `<= NOW()` |

**Índices:** 5 — por entidad+status, tenant+status+IAL, reproofing_at parcial, expires_at parcial, reviewer_id parcial.

**¿Necesita semilla?** No — se llena por el flujo de proofing del Motor de Identidad.

**¿Necesita interfaz?** Sí — panel de verificación de identidad en perfil del actor.

---

### T-166 · `bauth.idn_identity_consent` ✅ IMPLEMENTADA (v2.6.0)

**Bloque:** D00-B07 `consentimiento` · **Nivel DDL:** NIVEL 6 (después de T-165)

**Propósito:** Registro WORM del consentimiento de privacidad por sujeto de datos. Registra otorgamiento y retirada en la misma fila. GDPR Art. 7.1: el responsable debe demostrar que el titular consintió. Sin DELETE (evidencia forense).

**Normas:** GDPR Art. 6–7 · ISO/IEC 29184:2020 · Ley 1174 Bolivia Art. 12–15 · NIST SP 800-63-4 §10

| Columna | Tipo | Descripción |
|---|---|---|
| `consent_id` | UUID PK | UUIDv7 |
| `entity_id` | UUID FK RESTRICT | Sujeto — RESTRICT: evidencia forense |
| `tenant_id` | UUID FK RESTRICT | Tenant responsable del tratamiento |
| `policy_version` | TEXT | Versión de política vigente (ej: `2026-v2.1`) |
| `processing_scope` | TEXT[] | Alcances del tratamiento consentido |
| `legal_basis` | TEXT CHECK | CONSENT · CONTRACT · LEGAL_OBLIGATION · VITAL_INTEREST · PUBLIC_TASK · LEGITIMATE_INTEREST |
| `granted_via` | TEXT CHECK | WEB · API · APP · IN_PERSON · EMAIL |
| `ip_address` | INET NULL | IP de origen del consentimiento |
| `withdrawn_at` | TIMESTAMPTZ NULL | NULL = vigente · SET = retirado |
| `is_active` | BOOLEAN GENERATED | `withdrawn_at IS NULL` |

**WORM:** `REVOKE DELETE ON … FROM bauth_app_role` — registro histórico forense.

**¿Necesita semilla?** No — se llena en el flujo de onboarding del usuario.

**¿Necesita interfaz?** Sí — centro de privacidad del usuario (ver/retirar consentimientos activos).

---

### T-167 · `bauth.idn_identity_vc` ✅ IMPLEMENTADA (v2.6.0)

**Bloque:** D00-B08 `verifiable_credential` · **Nivel DDL:** NIVEL 6 (después de T-166, depende de T-165)

**Propósito:** Ciclo de vida completo de Verifiable Credentials emitidas por bAuth como Issuer o verificadas como Verifier. Soporta W3C VCDM 2.0 (Rec mayo 2025) y SD-JWT VC para selective disclosure.

**Normas:** W3C VC Data Model 2.0 · eIDAS 2.0 Reglamento UE 2024/1183 Art. 45 · NIST SP 800-63-4 §5 · W3C DID Core v1.1

| Columna | Tipo | Descripción |
|---|---|---|
| `vc_id` | UUID PK | UUIDv7 |
| `vc_uri` | TEXT UNIQUE | URN canónico o URL resolvible de la VC |
| `vc_type` | TEXT[] | Siempre incluye `"VerifiableCredential"` |
| `vc_format` | TEXT CHECK | VC_DATA_MODEL_1_1 · VC_DATA_MODEL_2_0 · SD_JWT_VC |
| `issuer_did` | TEXT | DID del emisor: `did:besu:SBOS:…` |
| `credential_subject` | JSONB | Claims del sujeto (sin PII en texto plano) |
| `proof` | JSONB | DataIntegrityProof eddsa-rdfc-2022 vía Vault |
| `status` | TEXT CHECK | ACTIVE · REVOKED · SUSPENDED · EXPIRED |
| `status_list_url` | TEXT NULL | W3C VC Status List 2021 — revocación escalable |
| `proofing_id` | UUID FK NULL SET NULL | Trazabilidad al proofing origen |

**Índices:** 7 — por entidad+status, vc_uri, issuer+status, subject_did, vc_type GIN, expiry parcial, credential_subject GIN jsonb_path_ops.

**¿Necesita semilla?** No — se llena al emitir o verificar VCs.

**¿Necesita interfaz?** Sí — wallet de credenciales del usuario + panel de emisión/revocación del administrador.

---

### T-168 · `bauth.idn_tenant_fal_config` ✅ IMPLEMENTADA (v2.6.0)

**Bloque:** D00-B09 `fal` · **Nivel DDL:** NIVEL 1 (después de T-011, junto a infraestructura de tenant)

**Propósito:** Configuración del Federation Assurance Level (FAL) por Relying Party registrada en bAuth como IdP OIDC. Define controles de seguridad requeridos (PKCE, DPoP, mTLS) y parámetros de aserción por RP. Constraints garantizan coherencia FAL↔controles.

**Normas:** NIST SP 800-63-4 §5 · OpenID Connect Core 1.0 · RFC 9449 (DPoP) · RFC 8705 (mTLS) · RFC 7636 (PKCE)

| Columna | Tipo | Descripción |
|---|---|---|
| `fal_config_id` | UUID PK | UUIDv7 |
| `tenant_id` | UUID FK CASCADE | Tenant propietario de la config |
| `rp_client_id` | TEXT | client_id OIDC del RP |
| `fal_level` | TEXT CHECK | FAL1 · FAL2 · FAL3 |
| `require_pkce` | BOOLEAN | FAL1+: PKCE RFC 7636 obligatorio |
| `require_dpop` | BOOLEAN | FAL2+: DPoP RFC 9449 |
| `require_mtls` | BOOLEAN | FAL3: mTLS RFC 8705 |
| `assertion_ttl_sec` | INTEGER | TTL del ID token (FAL3 ≤ 300s) |
| `allowed_redirect_uris` | TEXT[] | Sin wildcards en FAL2+ |

**Constraints de coherencia:** `chk_ifal_fal2_dpop` (FAL2/FAL3 requiere DPoP o mTLS) · `chk_ifal_fal3_mtls` (FAL3 requiere mTLS).

**¿Necesita semilla?** No — se llena al registrar cada Relying Party.

**¿Necesita interfaz?** Sí — panel de configuración de federación OIDC en administración de tenants.

---

### T-186 · `bauth.idn_identidad_lifecycle_event` ✅ IMPLEMENTADA (v2.7.0)

**Bloque:** D00 IAM Enterprise (JML) · **Nivel DDL:** NIVEL 6 (después de T-156)

**Propósito:** Registro inmutable de eventos de ciclo de vida JML (Joiner/Mover/Leaver). Cada transición laboral genera un evento que permite ajustar privilegios automáticamente y auditar todo el historial de movimientos de una entidad. Compatible con SCIM 2.0 provisioning events (RFC 7644 §3.4.3). Normas: NIST SP 800-53 AC-2(1) · IEC 62443 · ISO 27001 A.9.2.

**Normas:** NIST SP 800-63-3 §4 JML · SCIM 2.0 RFC 7644 §3.4.3 · ISO 27001 A.9.2

| Columna | Tipo | Descripción |
|---|---|---|
| `event_id` | UUID PK | UUIDv7 |
| `entity_id` | UUID FK RESTRICT | Entidad cuya vida laboral cambia |
| `tenant_id` | UUID FK CASCADE | Tenant de la entidad |
| `event_type` | TEXT CHECK | HIRED · TRANSFERRED · PROMOTED · ON_LEAVE · RETURNED · TERMINATED · REACTIVATED |
| `effective_at` | TIMESTAMPTZ | Cuándo entra en vigor el evento |
| `triggered_by` | UUID FK RESTRICT | Actor que disparó el evento |
| `policy_snapshot` | JSONB NULL | Estado de privilegios al momento del evento |
| `notes` | TEXT NULL | Notas del administrador |
| `ctx_id` | TEXT | Contexto de auditoría (SBOS-049) |

**Índices:** `idx_ile_entidad` · `idx_ile_tenant_type` · `idx_ile_triggered_by`

---

### T-169 · `bauth.idn_did_document` ✅ IMPLEMENTADA (v2.7.0)

**Bloque:** D00 IAM Enterprise (DID Resolver) · **Nivel DDL:** NIVEL 6 (después de T-156)

**Propósito:** Caché de documentos DID resueltos según W3C DID Core v1.1 CR (mar 2026). Evita llamadas externas al resolver en cada operación de autenticación — el resolver bAuth consulta esta tabla primero y actualiza cuando el documento caduca (`expires_at`). Soporta métodos DID: `did:web`, `did:key`, `did:ion`, `did:ebsi`, `did:peer`.

**Normas:** W3C DID Core v1.1 CR (mar 2026) · W3C DID Resolution v0.3 · eIDAS 2.0 EBSI

| Columna | Tipo | Descripción |
|---|---|---|
| `did_id` | UUID PK | UUIDv7 |
| `did` | TEXT UNIQUE | DID en formato canónico W3C. Ej: `did:web:example.com` |
| `did_method` | TEXT | Método DID (web, key, ion, ebsi, peer...) |
| `document` | JSONB | Documento DID resuelto (JSON-LD completo) |
| `status` | TEXT CHECK | ACTIVE · DEACTIVATED · INVALID · EXPIRED |
| `tenant_id` | UUID FK NULL | Tenant propietario (NULL = doc externo compartido) |
| `entity_id` | UUID FK NULL | Entidad local vinculada al DID |
| `resolved_at` | TIMESTAMPTZ | Fecha de última resolución |
| `expires_at` | TIMESTAMPTZ NULL | Expiración de caché (NULL = estático sin expirar) |
| `deactivated_at` | TIMESTAMPTZ NULL | Fecha de deactivation W3C |

**Índices:** `idx_idd_method` · `idx_idd_tenant` · `idx_idd_entidad` · `idx_idd_status` · `idx_idd_expires`

---

### T-187 · `bauth.idn_scim_attribute_map` ✅ IMPLEMENTADA (v2.7.0)

**Bloque:** D00 IAM Enterprise (SCIM) · **Nivel DDL:** NIVEL 6

**Propósito:** Mapeo bidireccional entre atributos locales de bAuth y el esquema SCIM 2.0. Permite provisioning y sync con directorios empresariales (Azure AD, Okta, OneLogin) sin depender de Keycloak (ADR-010). Cada fila mapea 1 atributo SCIM ↔ 1 atributo local. Incluye 10 seeds de mapeo estándar para User y EnterpriseUser.

**Normas:** RFC 7643 (SCIM Schema) · RFC 7644 (SCIM Protocol) · OpenID Connect Provider Metadata

| Columna | Tipo | Descripción |
|---|---|---|
| `map_id` | UUID PK | UUIDv7 |
| `tenant_id` | UUID FK NULL | Tenant (NULL = mapeo global por defecto) |
| `scim_resource` | TEXT CHECK | User · Group · EnterpriseUser · ServiceAccount · CustomResource |
| `scim_attr` | TEXT | Atributo SCIM (ej: `emails[type=work].value`) |
| `local_namespace` | TEXT | Namespace del atributo local |
| `local_attr_key` | TEXT | Clave del atributo local |
| `local_table` | TEXT CHECK | Tabla fuente del atributo local |
| `scim_mutability` | TEXT CHECK | readOnly · readWrite · immutable · writeOnly |
| `scim_returned` | TEXT CHECK | always · never · default · request |
| `transform_expr` | TEXT NULL | SQL expression de transformación (opcional) |

**UNIQUE:** `(tenant_id, scim_resource, scim_attr)` — un atributo SCIM tiene un único mapeo por tenant.

**Seeds incluidos:** 10 mapeos estándar (userName, displayName, name.*, emails, phoneNumbers, active, externalId, organization, employeeNumber).

---

### T-188 · `bauth.idn_dpia_registro` ✅ IMPLEMENTADA (v2.7.0)

**Bloque:** D00 IAM Enterprise (DPIA) · **Nivel DDL:** NIVEL 6 (después de T-156)

**Propósito:** Registro de Evaluaciones de Impacto Relativas a la Protección de Datos (DPIA) según GDPR Art. 35. Obligatorio para tratamientos de alto riesgo. Gestiona el ciclo completo: DRAFT → IN_REVIEW → APPROVED/REJECTED. Soporta consulta previa a autoridad de control (GDPR Art. 36) y revisión periódica obligatoria (GDPR Art. 35.11). Ref: WP248 rev01 + Guía AEPD 2023.

**Normas:** GDPR Art. 35/36 · WP248 rev01 (WP29) · Guía AEPD DPIA 2023 · ISO 29134:2017

| Columna | Tipo | Descripción |
|---|---|---|
| `dpia_id` | UUID PK | UUIDv7 |
| `tenant_id` | UUID FK RESTRICT | Tenant responsable del tratamiento |
| `titulo` | JSONB | Título multilingüe del DPIA |
| `descripcion` | JSONB | Descripción del tratamiento multilingüe |
| `finalidad` | TEXT | Finalidad del tratamiento (GDPR Art. 5.1.b) |
| `categorias_datos` | TEXT[] | Categorías de datos involucradas |
| `datos_especiales` | BOOLEAN | ¿Incluye Art. 9 datos especiales? |
| `riesgos` | JSONB | Lista de riesgos identificados |
| `riesgo_residual` | TEXT CHECK | LOW · MEDIUM · HIGH · VERY_HIGH |
| `medidas_mitigacion` | JSONB | Medidas técnicas y organizativas |
| `estado` | TEXT CHECK | DRAFT · IN_REVIEW · APPROVED · REJECTED · ARCHIVED · REQUIRES_DPA |
| `requiere_consulta_previa` | BOOLEAN | ¿Consulta previa DPA requerida? (Art. 36) |
| `responsable_id` | UUID FK RESTRICT | DPO o responsable del tratamiento |
| `next_review_at` | TIMESTAMPTZ NULL | Próxima revisión periódica (Art. 35.11) |

**Índices:** `idx_idpia_tenant` · `idx_idpia_estado` · `idx_idpia_responsable` · `idx_idpia_revision` · `idx_idpia_especiales`

---

## S8 — Privilegios (bauth)

> **Refactorización v2.3.0:** el DDL reordenó y renombró las tablas de S8. Mapa de cambios:
> | Manual anterior | DDL canónico (actual) | Cambio |
> |---|---|---|
> | T-171 `privilege_override` | T-173 `privilege_override` | Renumerado |
> | T-172 `privilege_assurance_log` | T-176 `privilege_assurance_audit` | Renombrado |
> | T-176 `privilege_sod_exception` | T-179 `privilege_exception_record` | Renombrado |
> | T-179 `privilege_menu_atom` | `bglobal.menu_item_atom` | Movida a bglobal |
> | *(nueva)* | T-171 `privilege_resource_atom` | Nueva — PAP para Kong PEP |
> | *(nueva)* | T-172 `privilege_delegation` | Nueva — auditoría de delegaciones |

### T-170 · `bauth.privilege_atom_grant` 🔄 REPLICA

**Propósito:** Grant de átomos de privilegio **por usuario** (no por rol genérico). Es la tabla central del motor de privilegios: registra qué átomos EVALUATION del árbol de políticas tiene activados cada usuario, con qué efecto (PERMIT/DENY) y de qué tipo (STANDARD/JIT/BREAKGLASS).

`REPLICA IDENTITY FULL`: bkernel-reactor recibe todos los cambios vía WAL/CDC para actualizar el BitmaskBundle en Redis.

---

#### Modelo 5 columnas (G-12)

El corazón de la tabla. Cinco columnas trabajan en conjunto para representar el estado de cada grant y evitar ambigüedades en la evaluación del PDP:

| Columna | Tipo | Semántica |
|---|---|---|
| `effect` | `BOOLEAN NOT NULL DEFAULT false` | Espejo del nodo EVALUATION en T-162. `true`=PERMIT, `false`=DENY. **Nunca editar directamente** — lo sincroniza `trg_t162_sync_effect_to_grants`. |
| `general` | `BOOLEAN NOT NULL DEFAULT true` | Control de precedencia. `true` (valor al crear) → el árbol manda: `effect` prevalece sobre `access`. `false` → el grant manda: `access` prevalece sobre `effect`. |
| `local` | `BOOLEAN GENERATED ALWAYS AS (NOT general) STORED` | Derivado de `general`. Columna calculada por PostgreSQL, solo para legibilidad visual. No tiene lógica propia. |
| `access` | `BOOLEAN NOT NULL DEFAULT true` | Override del operador. Forzado a `true` por trigger cuando `general=true`. Solo es editable con semántica real cuando `general=false`. |
| `reassess` | `BOOLEAN NULL` | Elegibilidad CAEP reactiva. `NULL`=hereda el default del tier del tenant (via `idn_tier_policy`). `true`=elegible para reevaluación. `false`=inmune (siempre en BREAKGLASS). |

**Flujo de decisión del PDP:**

```
¿general = true?
  ├─ SÍ → usa effect   (árbol manda; access está forzado a true por trigger)
  └─ NO → usa access   (grant manda; effect ignorado)

Si access = false (solo posible con general = false):
  └─ reassess = true está BLOQUEADO por chk_pag_reassess_coherencia
```

---

#### Constraint de coherencia

```sql
CONSTRAINT chk_pag_reassess_coherencia CHECK (
    NOT (access = false AND reassess = true)
)
```

Prohíbe la combinación `access=false AND reassess=true`. Un grant que ya está vetado explícitamente por el operador no puede ser candidato a reevaluación CAEP — no tiene sentido reevaluar algo que ya es DENY.

---

#### Índice parcial CAEP/risk (`idx_pag_reassess_eligible`)

```sql
CREATE INDEX IF NOT EXISTS idx_pag_reassess_eligible
    ON bauth.privilege_atom_grant(tenant_id, user_id)
    WHERE reassess = true
      AND status   = 'ACTIVE'
      AND (
          (general = true  AND effect = true)
          OR
          (general = false AND access = true)
      );
```

Cubre únicamente los grants que **están dando acceso efectivo** y son elegibles para reevaluación. El reactor CAEP y el evaluador de riesgo consultan este índice directamente sin escanear la tabla completa.

---

#### Triggers del modelo 5 columnas

**`trg_t162_sync_effect_to_grants`** — propaga `effect` del árbol a los grants

- Dispara: `AFTER UPDATE ON bauth.idn_roles_template`
- Función: `fn_sync_effect_from_tree()`
- Lógica: si el árbol modifica el `effect` de un nodo `tipo=evaluacion`, actualiza `effect` en todos los grants `ACTIVE/SUSPENDED` de ese átomo. Mantiene T-170 sincronizado con T-162 sin JOIN en el PDP.

**`trg_t170_sync_access_general`** — fuerza `access=true` cuando `general=true`

- Dispara: `BEFORE INSERT OR UPDATE ON bauth.privilege_atom_grant`
- Función: `fn_sync_access_to_general()`
- Lógica: si `general=true`, fija `access := true`. Previene que `access=false` aparezca cuando el árbol manda, lo cual sería un DENY visual falso que confundiría al PDP.

**`trg_validate_breakglass_grant`** — valida invariantes D1/D2/D3 en BREAKGLASS (G-20)

- Dispara: `BEFORE INSERT OR UPDATE OF grant_type, status ON bauth.privilege_atom_grant`
- Función: `fn_validate_breakglass_grant()`
- Lógica:
  - **D1** — fuerza `reassess := false` en todo grant BREAKGLASS (inmune a CAEP — RFC 9396)
  - **D2** — verifica que el rol sea de tier `SU` o tipo `EMERGENCY` (NIST AC-2(2)); rechaza con `BREAKGLASS_TIER_VIOLATION` si no cumple
  - **D3** — verifica que el tenant no tenga más de 2 grants BREAKGLASS activos (`ACTIVE` o `INACTIVE`); rechaza con `BREAKGLASS_LIMIT_EXCEEDED` si ya alcanzó el límite

---

#### `grant_type` — tipos de grant

| Valor | Semántica |
|---|---|
| `STANDARD` | Asignación normal por BOS Saga o panel de administración |
| `JIT` | Just-in-time: requiere `pam_jit_request` aprobada (T-182); tiene `valid_until` obligatorio |
| `BREAKGLASS` | Emergencia con dual control; fuerza `reassess=false`; máximo 2 por tenant |

---

#### ¿Cuándo se alimenta?

- **STANDARD**: al asignar un rol a un usuario (BOS Saga o admin panel)
- **JIT**: al aprobar `pam_jit_request` (T-182)
- **BREAKGLASS**: al activar `pam_breakglass_activation` (T-185)

#### Procesos necesarios

- **Job de expiración**: `WHERE valid_until <= NOW() AND status='ACTIVE'` → `UPDATE status='EXPIRED'`
- **CAEP reactor**: al recibir evento CAEP, busca grants con `reassess=true` via `idx_pag_reassess_eligible` y evalúa si revocar
- **bkernel CDC**: cada `INSERT/UPDATE/DELETE` → WAL → Redis actualización del BitmaskBundle

---

### T-170b · `bauth.privilege_atom_audit` 🔒 WORM 📦 PART

**Propósito:** Registro inmutable de cambios en grants con hash-chain SHA-256. Detecta alteración forense de la historia de privilegios.

**¿Cuándo se alimenta?** Por trigger en `privilege_atom_grant` al INSERT/UPDATE/DELETE. Particionada por mes para alta volumetría (millones de cambios/mes en producción).

**Hash-chain:** `SHA-256(prev_audit_hash || grant_id || operation || JSONB(new_data) || created_at)`. Permite detectar si alguien eliminó o modificó un registro de auditoría.

---

### T-171 · `bauth.privilege_resource_atom` ⭐ NUEVA

**Propósito:** Tabla PAP (Policy Administration Point) para Kong PEP. Liga recursos de red (protocolo + ruta + operación) con el átomo de control en T-162. Kong consulta esta tabla al arrancar para resolver decisiones en < 0.5 ns sin consultar bAuth en cada request.

**¿Qué registra?** `protocol_type` (WS_RPC/JSON_RPC/GRPC/UNIX_SOCKET/HTTP_EXT), `recurso`, `operacion`, `id_atom` → T-162, `domain_code` (D01-D37), `evaluation_path` (FAST/POLICY/EXTERNAL/PRECONDITION), `obligation` JSONB (`required_loa`).

**Semántica:** D01-D12 → FastPath (< 0.5 ns, bit=1 en JWT basta). D13-D37 → PolicyPath (Kong consulta bAuth PDP). `obligation NOT NULL` → Kong verifica LoA contra sesión en Redis ANTES de conceder acceso.

**Sin mapeo en esta tabla = DENY por defecto** (NIST SP 800-207: sin política explícita = denegado).

**¿Cuándo se alimenta?** Al registrar un nuevo endpoint o método RPC. Kong recarga via CAEP `catalog_change` sobre Unix socket sin reiniciar.

**¿Necesita interfaz en el frontend?** Sí — panel de configuración de recursos para administradores T0/SU.

---

### T-172 · `bauth.privilege_delegation` ⭐ NUEVA

**Propósito:** Registro de auditoría de asignaciones de rol temporal. Responde: "¿por qué tiene este usuario este rol temporal y quién lo autorizó?". **SOLO AUDITORÍA** — la validación real vive en T-170 (grants) y en `merge_roles` Rust.

**¿Qué registra?** `role_id`, `assignee_id`, `assigned_by`, `reason`, `valid_from/until`, `ctx_id`. La vigencia referenciada aquí es informativa; la vigencia real está en los átomos del rol en T-170.

**Flujo atómico:** INSERT en `privilege_delegation` + INSERT en `privilege_atom_grant` en una sola TX.

---

### T-173 · `bauth.privilege_override` *(antes T-171)*

**Propósito:** Excepciones DENY→PERMIT (o PERMIT→DENY) con quórum de aprobación. Para emergencias documentadas — no para gestión ordinaria de accesos.

**¿Cuándo se alimenta?** Por el administrador al aprobar una excepción específica. Requiere `approver_id` + `valid_until` obligatorio + `reason` documentada.

**Código:** El Motor de Identidad aplica overrides DESPUÉS de evaluar el grant base:
1. Evaluar BitmaskBundle (resultado base desde T-170)
2. Buscar overrides activos para `(user_id, id_atom)` con FK compuesta deferida
3. Si existe DENY_TO_PERMIT → forzar PERMIT aunque el bit esté en 0
4. Si existe PERMIT_TO_DENY → forzar DENY aunque el bit esté en 1

**Constraint:** un solo override activo del mismo tipo por `(tenant_id, id_atom, user_id, override_type)`.

---

### T-176 · `bauth.privilege_assurance_audit` *(antes T-172 `privilege_assurance_log`)*

**Propósito:** Auditoría de evaluaciones de obligación LoA realizadas por Kong PEP. Registra CÓMO se ejerció lo otorgado, no qué se otorgó (eso es T-170b). Una fila por request cuyo recurso en T-171 tenga `obligation IS NOT NULL`.

**¿Quién escribe?** Kong — no bAuth. Solo INSERT (REVOKE UPDATE/DELETE).

**¿Qué registra?** `grant_id`, `resource_id`, `required_loa`, `presented_loa`, `outcome` (PERMIT/STEP_UP_REQUIRED/DENIED), `session_id`, `evaluated_by` (kong-pep).

**Separación de responsabilidades:** T-170b audita QUÉ SE OTORGÓ y cuándo cambió el grant. T-176 audita CÓMO SE EJERCIÓ en runtime.

---

### T-179 · `bauth.privilege_exception_record` *(antes T-176 `privilege_sod_exception`)*

**Propósito:** Gobernanza de excepciones a políticas. Documenta el contexto de aprobación detrás de un override en T-173. El trigger SoD en T-170 consulta esta tabla antes de rechazar un INSERT por conflicto — si hay excepción activa para `(usuario, átomo)`, permite el grant.

**¿Cuándo se alimenta?** Al aprobar una solicitud de excepción a una política (SoD, tier, scope). `business_reason` con mínimo 50 caracteres (ISO 27001 exige toda excepción documentada).

**Campos clave:** `policy_violated`, `exception_type` (SOD_EXCEPTION/TIER_EXCEPTION/SCOPE_EXCEPTION/OTHER), `approved_by`, `valid_until`, `review_at` (≤ `valid_until`). No existen excepciones permanentes.

---

### `bglobal.menu_item_atom` *(antes T-179 `bauth.privilege_menu_atom`)*

**Cambio:** migrada al schema `bglobal` (menú es recurso compartido, no exclusivo de bauth). Liga ítems de menú (T-059) con átomos del árbol de políticas (T-162).

**¿Cuándo se alimenta?** Al registrar un nuevo ítem de menú. Toda funcionalidad nueva debe estar ligada a un átomo para quedar bajo control del PDP.

**Código (frontend PEP):**
```typescript
const canSee = (itemCode: string): boolean => {
  const menuAtoms = menuAtomMap[itemCode]; // cargado al inicializar
  return menuAtoms.some(atomId => bitmask.hasPermit(atomId));
};
```

---

## S9 — Sesión (bauth)

> **Refactorización v2.3.0:** las tablas de S9 fueron renombradas para alinear el prefijo con el schema funcional (`ses_`) y dividir/fusionar responsabilidades.
>
> | Manual anterior | DDL canónico (actual) | Cambio |
> |---|---|---|
> | T-181 `idn_sesion_activa` | T-181 `ses_session_log` | Renombrado + fusionó T-193 |
> | T-191 `idn_caep_event` | T-191 `ses_caep_event_log` | Renombrado |
> | T-192 `idn_ssf_delivery` | T-192 `ses_ssf_stream` | Dividida (solo configuración) |
> | *(parte de T-192)* | T-193 `ses_ssf_delivery_log` | Nueva — log de entregas SSF |
> | T-193 `idn_sesion_audit` | *(fusionada en T-181)* | Eliminada como tabla separada |

### T-181 · `bauth.ses_session_log` *(antes `idn_sesion_activa`)* 🔒 WORM parcial

**Propósito:** Log unificado de sesiones. Combina el estado activo (proyección de Redis) con el historial de eventos de sesión. La fuente operativa sigue siendo Redis; esta tabla es el failsafe ante falla de Redis y el registro permanente de auditoría.

**¿Qué registra?** `session_id`, usuario, tenant, rol activo, LoA, métodos de auth usados, IP, user-agent, JTI del JWT, token hash, fechas de inicio/expiración/última actividad, score de riesgo, step-up válido hasta. Eventos: LOGIN, LOGOUT, STEP_UP, REVOKE, IDLE_TIMEOUT.

**¿Cuándo se alimenta?** En cada autenticación exitosa y en cada evento del ciclo de vida de la sesión. `last_activity_at` se actualiza en cada request autenticado. `step_up_valid_until` al completar step-up RFC 9470.

**Procesos necesarios:**
- Job de limpieza: filas `expires_at < NOW()` y `revoked_at IS NOT NULL` se archivan y se purgan pasado el período de retención
- Kong PEP: valida `jti` en Redis (cache caliente) y en esta tabla (fallback)

**¿Necesita interfaz en el frontend?** Sí — "Mis sesiones activas" para el usuario + panel de sesiones para administradores.

---

### T-191 · `bauth.ses_caep_event_log` *(antes `idn_caep_event`)*

**Propósito:** Eventos CAEP recibidos por bAuth desde sistemas externos o detectados internamente. CAEP (RFC 8935) es el protocolo para comunicar cambios de estado de seguridad en tiempo real.

**¿Qué registra?** Tipo de evento (credential_change, session_revoked, risk_score_change, etc.), payload JSONB, origen, estado de procesamiento (RECEIVED/APPLIED/FAILED), resultado de la acción aplicada.

**¿Cuándo se alimenta?** Cuando bkernel-CDC detecta cambios relevantes via WAL, o cuando sistemas externos envían señales CAEP. El cliente CAEP de bAuth (commit 409095b) inserta aquí.

**Procesos necesarios:**
- Reactor bAuth: procesa eventos `WHERE processing_status='RECEIVED'` → aplica acción (revocar sesión, exigir step-up, etc.) → actualiza `processing_status='APPLIED'`

---

### T-192 · `bauth.ses_ssf_stream` *(antes `idn_ssf_delivery` — solo config)*

**Propósito:** Configuración de streams SSF (Shared Signals Framework, RFC 8936). Un stream es un canal de entrega de señales hacia un receptor externo. Cada stream tiene su endpoint, tipo de auth y estado de activación.

**¿Cuándo se alimenta?** Al registrar un nuevo receptor SSF (ej: otro tenant bAuth, un SIEM externo).

**Nota:** esta tabla es de configuración. El log de entregas individuales está en T-193.

---

### T-193 · `bauth.ses_ssf_delivery_log` *(antes parte de T-192)* 📦 PART

**Propósito:** Log de entregas de señales SSF. Cada intento de entrega (exitoso o fallido) queda registrado. El job de entrega usa este log para reintentos con backoff exponencial.

**¿Qué registra?** `stream_id` → T-192, `event_id` → T-191, intento nro, estado (PENDING/DELIVERED/FAILED), timestamp, respuesta HTTP del receptor.

**¿Cuándo se alimenta?** Por el job de entrega SSF cada vez que intenta enviar un evento a un receptor. Particionada por mes para alto volumen.

---

## S10 — Auditoría Access Review (bauth)

> **Refactorización v2.3.0:** las tablas de S10 fueron renombradas a terminología de certificación ISO 27001.
>
> | Manual anterior | DDL canónico (actual) | Cambio |
> |---|---|---|
> | T-177 `aud_access_review_campaign` | T-177 `aud_certification_campaign` | Renombrado |
> | T-178 `aud_access_review_item` | T-178 `aud_certification_review` | Renombrado |

### T-177 · `bauth.aud_certification_campaign` *(antes `aud_access_review_campaign`)*

**Propósito:** Campañas de certificación de accesos (Access Review / Certification). NIST 800-53 AC-2(7) requiere revisar los accesos de usuarios privilegiados al menos trimestralmente. El nombre "certification" alinea con ISO 27001 A.5.18 (revisión periódica de derechos de acceso).

**¿Qué registra?** Nombre, alcance (TENANT/USER/ROLE/ATOM), tipo (QUARTERLY/ANNUAL/OFFBOARDING/INCIDENT/SOD_REVIEW), fechas (`starts_at`, `ends_at`), días de recordatorio, responsable.

**¿Cuándo se alimenta?** El administrador de seguridad crea campañas manualmente. Las campañas QUARTERLY pueden generarse automáticamente por job trimestral.

**Procesos necesarios:**
- Al crear una campaña: el sistema genera filas en `aud_certification_review` para cada combinación (usuario, grant) dentro del scope
- Job de recordatorio: envía notificaciones via bNotify N días antes de `ends_at`
- Job de cierre: al llegar `ends_at`, si hay ítems sin decisión y `auto_revoke_on_expiry=true` → revocar grants pendientes

---

### T-178 · `bauth.aud_certification_review` *(antes `aud_access_review_item`)*

**Propósito:** Decisiones individuales de certificación de acceso. Un revisor toma una decisión (CERTIFY/REVOKE/ESCALATE/DEFER) por cada ítem de la campaña.

**¿Qué registra?** `campaign_id` → T-177, `user_id`, `grant_id` o `role_id` o `atom_id`, revisor asignado, `decision`, `decision_reason`, `decided_at`, `decision_deadline`.

**Procesos necesarios:**
- Al tomar decisión REVOKE: revocar el grant correspondiente en `privilege_atom_grant`
- Al ESCALATE: notificar al supervisor del revisor via bNotify
- Al DEFER: extender `decision_deadline` (máximo 1 extensión por ítem)

**¿Necesita interfaz en el frontend?** Sí — bandeja de certificación para cada revisor asignado.

---

## S11 — Riesgo / ITDR (bauth)

> **Refactorización v2.3.0:** la semántica de S11 cambió radicalmente. La tabla ya no es un log de eventos de riesgo — es una tabla de **políticas de respuesta adaptativa** por tenant. El log de eventos de riesgo se registra en `ses_session_log` (T-181).
>
> | Manual anterior | DDL canónico (actual) | Cambio |
> |---|---|---|
> | T-180 `risk_score_event` (log de eventos) | T-180 `ses_risk_policy` (reglas de respuesta) | Renombrado + semántica cambiada |

### T-180 · `bauth.ses_risk_policy` *(antes `risk_score_event` — log de eventos)*

**Propósito:** Tabla de **políticas de respuesta adaptativa al riesgo** por tenant. Define QUÉ hacer cuando el PDP recibe un evento CAEP con determinadas características. Equivale al libro de reglas del ITDR (Identity Threat Detection and Response).

**¿Qué registra?** Por tenant: `event_type` (tipo de evento CAEP que dispara la regla), `condition` JSONB (expresión evaluada contra el payload del evento — ej: `{"risk_score": {">": 70}}`), `action` (STEP_UP_REQUIRED/REVOKE_SESSION/SUSPEND_USER/NOTIFY_ONLY), `scope` (ALL_SESSIONS/CURRENT_SESSION/TENANT), `enabled`.

**Semántica:** una fila = una regla. Ejemplo: "Si llega un evento `risk_score_change` con score > 70 → revocar sesión actual". El PDP evalúa las reglas del tenant en orden de prioridad al procesar cada evento de T-191.

**Separación de responsabilidades:**
- T-180 define las **reglas** (configuración de políticas, cambia poco)
- T-191 `ses_caep_event_log` registra los **eventos** recibidos (log, cambia mucho)
- T-181 `ses_session_log` registra el **resultado** aplicado (estado de la sesión)

**¿Cuándo se alimenta?** El administrador de seguridad configura las reglas por tenant. Reglas por defecto se cargan en seed.

**¿Necesita interfaz en el frontend?** Sí — editor de políticas de riesgo por tenant para administradores de seguridad.

---

## S12 — PAM Privileged Access Management (bauth)

> **Refactorización v2.3.0:** las tablas de S12 fueron renombradas y renumeradas. `pam_tree_change_proposal` fue **retirada del DDL** (pendiente de diseño). Una tabla nueva fue añadida: `pam_nhi_secret_ref` (T-189).
>
> | Manual anterior | DDL canónico (actual) | Cambio |
> |---|---|---|
> | T-182 `pam_jit_request` | T-182 `pam_jit_request` | Sin cambio |
> | T-182b `pam_jit_audit` (WORM histórico) | T-182b `pam_jit_approval` (aprobación secuencial) | Renombrado + propósito nuevo |
> | T-183 `pam_breakglass_request` | T-185 `pam_breakglass_activation` | Renumerado + renombrado |
> | T-184 `pam_privileged_access_log` | T-184 `pam_session_record` | Renombrado |
> | T-185 `pam_credential_vault_ref` | T-183 `pam_credential_ref` | Renumerado + renombrado |
> | T-189 `pam_tree_change_proposal` | *(FALTA en DDL)* | Pendiente de diseño |
> | *(nueva)* | T-189 `pam_nhi_secret_ref` | Nueva — secretos NHI en Vault |

### T-182 · `bauth.pam_jit_request`

**Propósito:** Solicitudes JIT (Just-In-Time) de acceso elevado temporal. En lugar de dar privilegios permanentes, el usuario solicita acceso cuando lo necesita, especifica la justificación y duración, y los aprobadores del nivel correspondiente aprueban secuencialmente.

**¿Qué registra?** Solicitante, rol/átomos target, justificación, duración solicitada, estado (PENDING/APPROVED/ACTIVE/EXPIRED/REVOKED/REJECTED), quórum configurado, FK al grant JIT creado.

**¿Cuándo se alimenta?** Cuando un usuario necesita acceso temporal elevado.

**Flujo:**
1. Usuario crea solicitud → status=PENDING
2. Aprobadores de Nivel 1 aprueban → notificación a Nivel 2 (si aplica)
3. Al alcanzar quórum final → status=APPROVED
4. bAuth crea `privilege_atom_grant(grant_type='JIT', valid_until=now()+duration)` → status=ACTIVE
5. Al expirar → status=EXPIRED, grant revocado automáticamente

**¿Necesita interfaz en el frontend?** Sí — bandeja de solicitudes JIT + panel de aprobaciones.

---

### T-182b · `bauth.pam_jit_approval` *(antes `pam_jit_audit`)* — aprobación secuencial multi-nivel

**Propósito:** Registro de aprobaciones secuenciales por nivel. Una fila por nivel de aprobación, no por aprobador individual. El Nivel N+1 solo se notifica cuando el Nivel N fue aprobado.

**¿Qué registra?** `jit_request_id` → T-182, `nivel` (1, 2, 3…), `approver_id`, `decision` (APPROVED/REJECTED), `decided_at`, `notes`.

**Diferencia con diseño anterior:** ya no es un WORM de auditoría histórico — es la tabla de control del flujo de aprobación. El trail de auditoría permanente vive en `privilege_atom_audit` (T-170b).

**Regla:** un aprobador no puede aprobar su propia solicitud (`chk_pja_no_self`). El máximo de niveles lo define `pam_jit_request.quorum_config` JSONB.

---

### T-183 · `bauth.pam_credential_ref` *(antes T-185 `pam_credential_vault_ref`)*

**Propósito:** Punteros a credenciales rotatorias en HashiCorp Vault. El secreto NUNCA se almacena en PostgreSQL. Esta tabla registra dónde vive cada credencial y cuándo debe rotarse.

**¿Qué registra?** `owner_id` (HUMAN o NHI), `owner_type`, `credential_type` (PASSWORD/API_KEY/CERTIFICATE/SSH_KEY/SERVICE_TOKEN/OAUTH_TOKEN), `vault_path`, `vault_version`, `rotation_period`, `next_rotation_at`, `status`.

**Procesos necesarios:**
- Job de rotación: `WHERE next_rotation_at <= NOW() AND status='ACTIVE'` → llamar API Vault para rotar → actualizar `vault_version` y timestamps

---

### T-184 · `bauth.pam_session_record` *(antes `pam_privileged_access_log`)* 🔒 WORM

**Propósito:** Metadatos de sesiones de acceso privilegiado (JIT o break-glass activos). Referencia a la grabación de sesión en MinIO para forensia. El contenido real de la grabación vive en MinIO, no en PostgreSQL.

**¿Qué registra?** `jit_request_id` o `breakglass_id`, usuario, tenant, rol activo, `started_at`, `ended_at`, `duration_seconds` (columna GENERATED ALWAYS AS), `recording_ref` (URL MinIO), `termination_reason`.

**¿Cuándo se alimenta?** Al iniciar y al cerrar cada sesión privilegiada. `duration_seconds` se calcula automáticamente.

**¿Necesita interfaz en el frontend?** Sí — visor de sesiones privilegiadas para auditores.

---

### T-185 · `bauth.pam_breakglass_activation` *(antes T-183 `pam_breakglass_request`)*

**Propósito:** Activaciones de acceso de emergencia (break-glass). Para situaciones de crisis donde los procesos normales son insuficientes por urgencia. Control dual obligatorio: mínimo 2 aprobadores, nunca autoaprobación.

**¿Qué registra?** `incident_ref` (ticket de incidente obligatorio), justificación, estado (PENDING_APPROVAL/ACTIVE/DEACTIVATED/REVIEWED), `approved_by[]`, `activated_at`, `deactivated_at`, `post_review_due_at` (= `activated_at + 24h`), `reviewed_at`, `review_outcome`.

**Flujo:**
1. Usuario declara emergencia → status=PENDING_APPROVAL + alerta inmediata a equipo de seguridad
2. 2+ personas aprueban (AAL3 requerido — `chk_pbga_dual_control`) → status=ACTIVE → grant BREAKGLASS creado
3. Al resolver el incidente → DEACTIVATE → grant revocado → status=DEACTIVATED
4. Revisión post-incidente obligatoria antes de `post_review_due_at` → status=REVIEWED

**¿Por qué el grant BREAKGLASS ignora CAEP?** Es inmune a políticas de riesgo adaptativo durante la emergencia — no se revoca automáticamente por señales de riesgo, requiere desactivación manual explícita.

**¿Necesita interfaz en el frontend?** Sí — panel de emergencias con botón de activación grande + alerta a todos los administradores.

---

### T-189 · `bauth.pam_nhi_secret_ref` ⭐ NUEVA

**Propósito:** Referencia específica de secretos para NHI (Non-Human Identities): CI/CD pipelines, service accounts, scripts automáticos. Se complementa con T-183 (`pam_credential_ref`) — esta tabla agrega los campos específicos de NHI que las credenciales humanas no necesitan.

**¿Qué agrega sobre T-183?** `nhi_agent_id` → T-190 (identidad del agente), `rotation_policy` (ON_USE para CI/CD = rotar cada vez que se usa), `max_ttl` (7-30 días vs 90 días para humanos), `last_used_at`, `usage_counter`, `consumer_systems[]`.

**Semántica de rotación:**
- `SCHEDULED`: rotar según calendario (período estándar)
- `ON_USE`: rotar inmediatamente después de cada uso (pipelines CI/CD de alto riesgo)
- `ON_BREACH_ONLY`: rotar solo ante incidente (secrets de emergencia)

**¿Necesita interfaz en el frontend?** Sí — inventario de secretos NHI con estado de rotación para administradores de seguridad.

---

### ⚠️ FALTANTE — `bauth.pam_tree_change_proposal`

**Estado en DDL:** **NO EXISTE** en `SBOS_db_V2_DDL.sql`. La tabla fue planeada para el flujo de aprobación de cambios al árbol de políticas (T-162) con quórum, pero aún no fue diseñada definitivamente en el DDL.

**Propósito planeado:** Propuestas de cambio al árbol PAP (T-162) con quórum de aprobación. Ningún cambio al árbol de políticas se aplica directamente — pasa por propuesta + quórum.

**Estado:** pendiente de diseño. El flujo queda bloqueado hasta que esta tabla se añada al DDL.

---

## Apéndice A — Tablas WORM del sistema

*(Actualizado v2.3.0 — nombres canónicos del DDL)*

| Tabla (DDL canónico) | Motivo WORM | Particionada |
|----------------------|-------------|:------------:|
| `bcalendar.cal_notification_log` | Evidencia de alarmas enviadas | No |
| `bauth.idn_roles_template_history` (T-163) | Cambios al árbol de políticas PAP | No |
| `bauth.idn_roles_ver_b01_audit_log` (T-152) | Historia de versiones cerradas de roles | No |
| `bauth.privilege_atom_audit` (T-170b) | Cambios en grants de privilegio | Sí (por mes) |
| `bauth.ses_session_log` (T-181) | Eventos del ciclo de vida de sesiones (fusionó T-193 anterior) | No |
| `bauth.ses_ssf_delivery_log` (T-193) | Entregas de señales SSF | Sí (por mes) |
| `bauth.privilege_assurance_audit` (T-176) | Evaluaciones de obligación LoA por Kong PEP | No |
| `bauth.idn_roles_nhi_lifecycle_event` (T-190b) | Ciclo de vida NHI | No |
| `bauth.pam_session_record` (T-184) | Metadatos de sesiones de acceso privilegiado | No |

**Tablas eliminadas en v2.3.0:**
- `bauth.idn_sesion_audit` → fusionada en `ses_session_log` (T-181)
- `bauth.pam_jit_audit` → reemplazada por `pam_jit_approval` (T-182b), flujo, no WORM
- `bauth.pam_privileged_access_log` → renombrada a `pam_session_record` (T-184)

---

## Apéndice B — Dependencias de creación

*(Actualizado v2.3.0 — nombres canónicos del DDL)*

El orden de creación de la DDL (NIVEL 0-11) es:

```
NIVEL 0 — bglobal
1. Extensiones + ENUMs globales + SEQUENCE
2. bglobal.global_language, global_country, global_currency, geo_timezone (catálogos raíz)
3. bglobal.menu_item_atom, global_config

NIVEL 1 — Tenant
4. bauth.idn_tenant
5. bauth.idn_tenant_currencies, languages, verification, config, domain, network

NIVEL 2 — Calendario
6. bcalendar.cal_fiscal_year, cal_calendar, cal_event, cal_alarm, cal_notification_log,
           cal_holiday, cal_schedule, cal_overtime_policy, cal_break_policy
7. bauth.idn_tenant_calendar_assignment

NIVEL 3 — Roles
8. bauth.idn_roles_iga_category [catálogo IGA — sin FKs a otras tablas bauth]
9. bauth.idn_roles_rol_type, idn_roles_rol_tier

NIVEL 4 — Versionado (ENUMs y columnas T-041)
   [Los ENUMs de versionado se crean junto con las extensiones globales en paso 1]

NIVEL 5 — Árbol de Políticas
10. bauth.privilege_verb, privilege_verb_conflict
11. bauth.idn_policy_node_type
12. bauth.idn_roles_template (+triggers trg_irt_atom_position, trg_t162_sync_effect_to_grants)
    [FK DEFERIDA a idn_roles_rol_hierarchical]
13. bauth.idn_roles_rol_hierarchical [FK DEFERIDA a idn_roles_template]
    + trigger B02 (trg_irrh_b02_validity)
13b. bauth.idn_roles_rol_lifecycle_event [WORM B02]
14. bauth.idn_roles_rol_closure
15. bauth.idn_roles_template_history (WORM)
16. bauth.idn_roles_ver_b01_audit_log, idn_roles_ver_b03_approval_queue,
           idn_roles_ver_b01_retention_policy, idn_roles_ver_contract_revision_log

NIVEL 6 — Identidad D00
17. bauth.idn_identity_entity, idn_identity_attribute
    [T-158..T-161 son STUBS sin CREATE TABLE: idn_identity_attribute_history, idn_identity_requirement, idn_identidad_sinonimo, idn_identidad_sinonimo_sync]
18. bauth.idn_roles_nhi_identity, idn_roles_nhi_lifecycle_event,
           idn_roles_nhi_certification, idn_roles_nhi_agent_identity

NIVEL 7 — Privilegios
19. bauth.privilege_atom_grant (+REPLICA IDENTITY FULL), privilege_atom_audit (particionada 3 meses)
20. bauth.privilege_resource_atom (PAP → Kong PEP)
21. bauth.privilege_delegation (auditoría delegaciones)
22. bauth.privilege_override
23. bauth.privilege_assurance_audit
24. bauth.privilege_exception_record
25. bglobal.menu_context, menu_item_context

NIVEL 8 — Sesión
26. bauth.ses_session_log
27. bauth.ses_caep_event_log
28. bauth.ses_ssf_stream
29. bauth.ses_ssf_delivery_log (particionada)

NIVEL 9 — Auditoría
30. bauth.aud_certification_campaign
31. bauth.aud_certification_review

NIVEL 10 — Riesgo / ITDR
32. bauth.ses_risk_policy

NIVEL 11 — PAM
33. bauth.pam_jit_request
34. bauth.pam_jit_approval
35. bauth.pam_breakglass_activation
36. bauth.pam_credential_ref
37. bauth.pam_session_record
38. bauth.pam_nhi_secret_ref
```

**Nota:** `bauth.pam_tree_change_proposal` (flujo de aprobación para cambios al árbol PAP) **no existe en el DDL actual** — pendiente de diseño.

---

## Apéndice C — FK deferida idn_roles_hierarchical ↔ idn_roles_template

Existe una dependencia circular entre T-041 y T-162:
- T-041 (`idn_roles_rol_hierarchical.template_id`) → FK a T-162
- T-162 (`idn_roles_template.verb_id`) → FK a T-174 (no circular)

La DDL resuelve esto con `DEFERRABLE INITIALLY DEFERRED` en la FK de T-041 → T-162. Esto permite crear T-162 primero, luego T-041, y luego agregar la constraint deferida. PostgreSQL valida la FK al COMMIT de la transacción (no en cada INSERT).

---

## S13 — Usuarios (bauth)

**NIVEL 12 · Tablas:** T-320, T-321, T-322  
**Ref:** NIST SP 800-63-4 §3 · SCIM 2.0 RFC 7643/7644 · OWASP ASVS v5.0 §2.5

### Arquitectura de tres capas NIST SP 800-63-4

```
T-156 idn_identity_entity    ← Capa 1: Identidad organizacional (quién es)
T-320 idn_user               ← Capa 2: Subscriber Account (cómo accede, por tenant)
T-330 auth_credential        ← Capa 3: Authenticator (con qué se autentica)
```

Un mismo `entity_id` puede tener cuentas en distintos tenants. La cuenta es el objeto de login; la identidad es el objeto de identidad.

### T-320 — idn_user

| Columna | Tipo | Descripción |
|---------|------|-------------|
| `user_id` | UUID PK | UUIDv7 — identificador único de cuenta |
| `tenant_id` | UUID FK → idn_tenant | Tenant al que pertenece esta cuenta |
| `entity_id` | UUID FK → idn_identity_entity | Identidad organizacional subyacente (T-156) |
| `username` | TEXT | Nombre de usuario único por tenant |
| `status` | TEXT | `PENDING_ACTIVATION` / `ACTIVE` / `LOCKED` / `SUSPENDED` / `DEACTIVATED` / `ARCHIVED` |
| `registration_method` | TEXT | `ADMIN` / `SELF_SERVICE` / `PROVISIONED` / `FEDERATED` |
| `ial_achieved` | TEXT | Nivel de proofing alcanzado: `IAL1` / `IAL2` / `IAL3` |
| `loa_min` | TEXT | LoA mínimo requerido para login: `AAL1` / `AAL2` / `AAL3` |
| `failed_attempts` | INT | Contador de fallos consecutivos (reset en éxito) |
| `lockout_until` | TIMESTAMPTZ | Hasta cuándo está bloqueada la cuenta (NULL = no bloqueada) |
| `password_changed_at` | TIMESTAMPTZ | Última vez que se cambió la contraseña |
| `must_change_password` | BOOLEAN | Fuerza cambio de clave en próximo login |
| `last_login_at` | TIMESTAMPTZ | Timestamp del último login exitoso |
| `last_login_ip` | INET | IP del último login exitoso |
| `scim_external_id` | TEXT | ID externo SCIM para provisionamiento federado |
| `wallet_id` | UUID | FK futura a billetera digital (T-380) |

**Índices:** `(tenant_id, status)` filtrado a ACTIVE/LOCKED · `entity_id` · `lockout_until` WHERE NOT NULL

**Invariantes:**
- UNIQUE `(tenant_id, username)` — username único por tenant
- UNIQUE `(tenant_id, entity_id)` — una entidad = una cuenta por tenant
- `failed_attempts` NUNCA se decrementa manualmente; solo se resetea a 0 en login exitoso
- Bloqueo por intentos: el PrivilegeEngine actualiza `failed_attempts` y `lockout_until`

### T-321 — idn_user_history

WORM hash-chain. Audit log de cambios en T-320. `REVOKE UPDATE, DELETE FROM bauth_app_role`.

Campos clave: `field` · `old_value` (JSONB) · `new_value` (JSONB) · `changed_by` · `reason` · `prev_hash`.

**Inmutabilidad:** cada inserción encadena el `prev_hash` del registro anterior para detectar manipulaciones.

### T-322 — idn_user_recovery

Métodos de recuperación de cuenta: `BACKUP_EMAIL` · `BACKUP_PHONE` · `TRUSTED_CONTACT` · `ADMIN_OVERRIDE`.

`value_hash` almacena SHA-256 del valor — nunca el valor en claro. Cumple OWASP ASVS v5.0 §2.5.

---

## S14 — Autenticación (bauth)

**NIVEL 13 · Tablas:** T-330..T-338  
**Ref:** NIST SP 800-63B-4 · FIDO2 W3C L3 · RFC 9449 DPoP · RFC 9470 Step-Up · PCI DSS 4.0 Req 8

### T-330 — auth_credential

Binding autenticador ↔ cuenta. **No almacena secretos** (→ T-331/332/333).

| Columna clave | Descripción |
|--------------|-------------|
| `method_code` | Referencia al catálogo T-335 (`auth_method.code`) |
| `status` | `PENDING_ACTIVATION` / `ACTIVE` / `SUSPENDED` / `REVOKED` / `EXPIRED` |
| `loa_provided` | AAL que provee este autenticador |
| `is_phishing_resistant` | `TRUE` para FIDO2/WebAuthn — activa rutas de mayor privilegio |
| `is_primary` | El autenticador principal (solo uno por método activo) |
| `valid_from` / `valid_until` | Ventana de validez del autenticador |
| `revoked_at` + `revocation_reason` | Revocación en < 30s (NIST SP 800-63B §7.2) |

### T-331 — auth_credential_secret

Secretos cifrados Vault transit. `REVOKE UPDATE (secret)`.

- **Tipos:** `ARGON2ID_HASH` · `TOTP_SEED_ENC` · `HOTP_SEED_ENC` · `RECOVERY_CODE_HASH` · `PUSH_PUBKEY_ED25519`
- **Argon2id:** `m=64MB, t=3, p=4` (NIST SP 800-63B-4 §5.1.1 — MemHard KDF)
- `vault_key_version` — versión de la clave de cifrado Vault; permite rotación

### T-332 — auth_credential_fido2

Registro completo de credenciales FIDO2/Passkey (W3C WebAuthn L3).

`sign_count` anti-replay §6.1 — incrementa en cada autenticación. Si el contador recibido ≤ `sign_count` almacenado → sospecha de clonación.

`backup_eligible` / `backup_state` — soporte de Passkey sincronizados (multi-dispositivo).

### T-333 — auth_credential_x509

Certificados X.509 para mTLS (RFC 8705). Distingue origen:
- `VAULT_INTERNAL` — PKI interna SBOS Root CA
- `ADSIB_EXTERNA` — certificados Ley 164 Bolivia con validez jurídica
- `ENTERPRISE_PKI` — PKI corporativa del tenant
- `SELF_SIGNED` — solo para desarrollo (prohibido en producción)

`oid_adsib` + `is_adsib_qualified` — marcador de certificado calificado ADSIB. `ocsp_url` para verificación de revocación en tiempo real.

### T-334 — auth_attempt_log (particionada)

WORM particionada por `attempted_at` (mensual). `REVOKE UPDATE, DELETE FROM bauth_app_role`.

Registra TODOS los intentos: éxito, fallo, lockout, step-up requerido, credencial revocada.

**ITDR (Identity Threat Detection & Response):**
- Índice `(ip_address, attempted_at DESC)` filtrado a FAILURE/INVALID_USER → detección credential stuffing
- Índice `(user_id, attempted_at DESC)` filtrado a FAILURE → detección brute-force por cuenta

### T-335 — auth_method (MethodRegistry)

Catálogo declarativo de métodos. **El sistema de autenticación NO requiere recompilación para nuevos métodos.**

**6 categorías:**
| Categoría | Descripción |
|-----------|-------------|
| A | Contraseña / Secreto memorizable |
| B | OTP (TOTP, HOTP, Email OTP, SMS OTP) |
| C | Hardware / Biometría (FIDO2, WebAuthn, Passkey) |
| D | Certificados / PKI (X.509 mTLS) |
| E | Federado (SAML2, OIDC, Social) |
| F | Especiales (Kerberos, CIBA, Device Auth, Recovery) |

`is_phishing_resistant` + `is_mfa_component` — metadatos para el PDP al armar challenge MFA.

### T-336 — auth_policy

Políticas de autenticación por contexto (tenant / dominio / recurso).

`allowed_methods[]` — métodos permitidos en este contexto.  
`required_methods[]` — al menos uno de estos debe estar presente.  
`step_up_trigger` (JSONB) — condiciones que activan RFC 9470 Step-Up.  
`max_session_secs` — timeout de sesión máximo para este contexto.

### T-337 — auth_config

Parámetros técnicos del motor en tiempo de ejecución. **Sin hardcode.**

Ejemplos de claves: `lockout.max_failed_attempts` · `lockout.duration_minutes` · `totp.window_size` · `argon2.memory_kib` · `dpop.max_clock_skew_seconds`.

Cada clave tiene `effective_at` — permite programar cambios futuros de configuración.

### T-338 — auth_crypto_algorithm

Inventario de algoritmos con estado: `APPROVED` / `DEPRECATED` / `FORBIDDEN`.

**APPROVED en producción SBOS:**
- KDF: `ARGON2ID` (identidades) · `HKDF-SHA256` (derivación)
- Simétrico: `AES-256-GCM`
- Firma: `ED25519` · `ECDSA-P256`
- PQC (post-cuántico): `ML-KEM-768` · `ML-DSA-65`

**FORBIDDEN (verificado):** `MD5` · `SHA-1` · `RSA-1024` · `DES` · `3DES`

---

## S15 — Firma Digital D13 (bauth)

**NIVEL 14 · Tablas:** T-350..T-357  
**Ref:** Ley 164 Bolivia · eIDAS 2.0 · RFC 5280 · RFC 3161 · ADSIB-FD-POLT-015 v2.3

### Doble motor de firma

| Motor | Algoritmo | Validez | Casos de uso |
|-------|-----------|---------|-------------|
| `INTERNAL_VAULT` | Ed25519 (Vault PKI) | SBOS interna + contratos digitales | JWT, tokens, documentos internos |
| `EXTERNAL_ADSIB` | RSA-SHA256 (ADSIB Bolivia) | Jurídica Ley 164 | Facturas SIN, contratos legales, DDJJ |

### T-350 — sig_key

Referencias a llaves en Vault. **NUNCA contiene clave privada** (solo `vault_path` + `vault_key_version`).

`purpose`: `JWT_SIGNING` · `DOCUMENT_SIGNING` · `CODE_SIGNING` · `TLS_CLIENT` · `ADSIB_BILLING` · `ADSIB_CONTRACTS`

`next_rotation` — Job de rotación automática cada 90 días (Ed25519) o según ADSIB (RSA anual).

### T-351 — sig_certificate

Catálogo de certificados X.509 en PEM público. `cert_pem` = solo parte pública.

**Jerarquía ADSIB Bolivia:** ATT → ADSIB → Persona Natural / Jurídica / Firma Automática.

`ocsp_verified_at` — timestamp de última verificación OCSP en línea.

### T-352 — sig_crl

CRL activas descargadas de las CA. Job: ADSIB cada hora, Vault cada 24h.

### T-353 — sig_operation_log

WORM. Log forense de **cada acto de firma**. `REVOKE UPDATE, DELETE FROM bauth_app_role`.

`merkle_batch_id` + `onchain_tx_hash` — anclaje on-chain para no repudio.

### T-354 — sig_document_hash

WORM. Hashes SHA-256 (+ SHA3-256 opcional) de documentos firmados.  
`purge_after` — retención Ley 164: 8 años documentos SIN · 7 años contratos.

### T-355 — sig_timestamp

WORM. Timestamps calificados RFC 3161. Proveedor TSA Bolivia (ADSIB) o Vault interno.

### T-356 — sig_adsib_lifecycle

WORM. Ciclo de vida de certificados ADSIB. Máximo 4 reemisiones (ADSIB-FD-POLT-015 v2.3 §8).

Alertas automáticas a 30d / 15d / 7d antes de vencimiento → Job: `fn_job_adsib_cert_expiry_check`.

### T-357 — sig_document_policy

Política de motor de firma por tipo de documento. Define:
- `engine_required`: `INTERNAL_VAULT` / `EXTERNAL_ADSIB` / `BOTH`
- `internal_profile` / `external_profile`: perfiles JWS/XAdES/CAdES/PAdES
- `requires_timestamp` + `requires_blockchain_anchor`
- `min_retention_years` — determina `purge_after` en T-354

---

## D12 — Blockchain (bauth)

**NIVEL 15 · Tablas:** T-358..T-362  
**Ref:** RFC 6962 (Merkle) · FIPS 202 (Keccak-256) · QBFT/IBFT 2.0 · Arbitrum One

### Arquitectura de anclaje dual

```
SBOS Events → blk_merkle_leaf (T-360) → blk_merkle_batch (T-359) → Merkle Root
                                                                          ↓
                                                         blk_anchor (T-358) → Arbitrum L2 / Besu QBFT
```

### T-358 — blk_anchor

WORM. Registra cada anclaje Merkle on-chain. `REVOKE UPDATE, DELETE FROM bauth_app_role`.

**Chains:** `ARBITRUM_ONE` (L2 Ethereum, costos bajos) · `BESU_QBFT` (red privada D12, cero gas externo).

`tx_hash` + `block_number` — evidencia de anclaje verificable públicamente.

### T-359 — blk_merkle_batch

Agrupa hojas para el cómputo del árbol Merkle. Hasta ~1M hojas por lote.

Estados: `OPEN` → `CLOSED` → `COMPUTING` → `ANCHORED` / `FAILED`

### T-360 — blk_merkle_leaf

WORM. Cada hoja del árbol Merkle. `leaf_hash` = Keccak-256 del evento.  
`merkle_proof[]` — array de hashes de hermanos para verificación offline con `bos-verify`.

UNIQUE `(batch_id, leaf_index)` garantiza integridad del árbol.

### T-361 — blk_account

Cuentas Besu QBFT por entidad. `balance_cache` = CACHE — la fuente de verdad es `SettlementEngine.sol` (verificado VPS 2026-06-22).

`cache_at` — timestamp del cache; si es > 15 min se considera stale y se refresca vía RPC.

### T-362 — blk_reconciliation

Conciliación on-chain ↔ PostgreSQL cada 15 minutos. `delta` = `balance_onchain` − `balance_prev`.

`status`: `OK` / `DISCREPANCY` (alerta SIEM) / `CORRECTED` (solo con aprobación PAM JIT).

---

## S16 — Federación / OIDC (bauth)

**NIVEL 16 · Tablas:** T-365, T-366, T-367  
**Ref:** RFC 6749 (OAuth2) · RFC 9449 (DPoP) · RFC 8705 (mTLS) · FAPI 2.0 · NIST SP 800-63-4 §6

### T-365 — fed_client

Registro de clientes OAuth2/OIDC. `client_secret` NUNCA aquí — almacenado en Vault (`vault_secret_path`).

**Perfiles de seguridad:**
| Tipo | PKCE | DPoP | mTLS | Perfil |
|------|------|------|------|--------|
| `CONFIDENTIAL` | Recomendado | Opcional | Opcional | Estándar |
| `PUBLIC` (SPA/móvil) | **Obligatorio** | Opcional | No | Básico |
| `M2M` | N/A | Recomendado | **Obligatorio** | FAPI2/Avanzado |

`fapi_profile`: `BASELINE` / `ADVANCED` / `FAPI2` — activa validaciones adicionales en el PEP.

### T-366 — fed_provider_ext

IdPs externos federados. Protocolos: `OIDC` · `SAML2` · `GOOGLE` · `GITHUB` · `LINKEDIN` · `MICROSOFT_ENTRA`.

`fal`: Federation Assurance Level (NIST SP 800-63-4 §6):
- `FAL1` — bearer token (mínimo)
- `FAL2` — token bound (DPoP/mTLS)
- `FAL3` — criptográficamente bound al autenticador del holder

`attr_mapping` (JSONB) — mapeo de claims del IdP externo a atributos SBOS.

### T-367 — fed_token_issued (particionada)

Tokens emitidos: SHA-256 del token — **NUNCA el valor en claro**. Particionada por `issued_at` (mensual).

**PK compuesto** `(token_id, issued_at)` — requerido por PostgreSQL para tablas particionadas por rango.

`dpop_jkt` — JWK Thumbprint del par de llaves DPoP (RFC 9449 §4.2).  
`mtls_cert_fp` — fingerprint del certificado mTLS de binding (RFC 8705).  

**Revocación:** `revoked_at` + `revocation_reason`. La revocación es en < 30s (job Redis invalidation → bitmask).

---

## S17 — Billetera Digital (bauth)

**NIVEL 17 · Tablas:** T-380, T-381, T-382, T-383  
**Ref:** W3C VCDM 2.0 · OID4VP · OpenID4VCI · eIDAS 2.0 Art. 5a · GDPR Art. 7.3

### Arquitectura EUDI Wallet soberana

```
idn_identity_entity (T-156)
        │
        └── wallet (T-380)          ← Billetera soberana, DID did:sbos:{tenant}:{entity}
                │
                ├── wallet_item (T-381)           ← Puntero a credential/cert/FIDO2/DID doc
                ├── wallet_presentation_log (T-382)  ← WORM: log de presentaciones VP
                └── wallet_issuance_log (T-383)      ← WORM: log de emisión VCs
```

### T-380 — wallet

Billetera digital soberana. **Un entity_id = una wallet por tenant.**

`did` — DID canónico SBOS: `did:sbos:{tenant_slug}:{entity_uuid}`. UNIQUE global.  
`did_anchored` + `did_tx_hash` — anclaje on-chain del documento DID (Besu QBFT).  
`backup_method`: `NONE` (default seguro) · `ENCRYPTED_CLOUD` (clave derivada de passkey, nube soberana).

### T-381 — wallet_item

Puntero a ítems de billetera. **No duplica datos** — referencia al objeto fuente por `ref_id`.

| `type` | `ref_id` apunta a |
|--------|-------------------|
| `VC` | `idn_identity_vc.vc_id` (T-167) |
| `FIDO2` | `auth_credential_fido2.fido2_id` (T-332) |
| `X509_CERT` | `auth_credential_x509.x509_id` (T-333) |
| `DID_DOC` | `idn_did_document.did_doc_id` (T-169) |
| `SIG_CERT` | `sig_certificate.cert_id` (T-351) |

`sd_enabled` — activa SD-JWT para presentaciones selectivas.  
`public_attrs[]` — atributos que el holder ha marcado como siempre divulgables.

### T-382 — wallet_presentation_log (particionada)

WORM. Log de cada presentación VP (OID4VP). Particionada por `presented_at` (mensual).  
`REVOKE UPDATE, DELETE FROM bauth_app_role`. **PK compuesto** `(presentation_id, presented_at)`.

`revealed_attrs[]` — qué atributos se revelaron en presentación selectiva.  
`verifier_did` — DID del verificador (verifiable verifier, eIDAS 2.0 §5.3).  
`outcome`: `ACCEPTED` / `REJECTED` / `PARTIAL`.

**GDPR Art. 7.3** — el titular puede solicitar log de todas sus presentaciones y revocar consentimiento.

### T-383 — wallet_issuance_log

WORM. Log de cada VC emitida. `REVOKE UPDATE, DELETE FROM bauth_app_role`.

`protocol`: `OPENID4VCI` (estándar EUDI) · `DIRECT_ISSUE` (interno SBOS) · `IMPORTED` (migración).  
FK `vc_id` → `idn_identity_vc` (T-167) — trazabilidad completa emisión → almacenamiento → presentación.

---

## S14 catálogos — MethodRegistry (bauth)

**NIVEL 18 · Tablas:** T-384, T-385, T-386  
**Ref:** RFC 6749 · RFC 8628 · RFC 8693 · CIBA · FAPI 2.0 · NIST SP 800-63B-4

Estos tres catálogos completan el MethodRegistry declarativo iniciado en NIVEL 13 (T-335..T-338). Permiten que el motor de autenticación sea completamente configurable sin recompilar.

### T-384 — auth_federation_protocol

Catálogo de protocolos de federación. **8 seeds activos:**

| `code` | AAL máx | FAL soportado | Phishing-resistant |
|--------|---------|--------------|-------------------|
| `SAML_2_0` | AAL2 | FAL1/FAL2 | No |
| `OIDC_CORE_1_0` | AAL2 | FAL1/FAL2 | No |
| `OAUTH2_PKCE` | AAL2 | FAL1/FAL2 | No |
| `OAUTH2_DEVICE` | AAL1 | FAL1 | No |
| `OAUTH2_TOKEN_EXCHANGE` | AAL2 | FAL1/FAL2 | No |
| `CIBA` | AAL2 | FAL1/FAL2 | No |
| `FAPI_2_0` | AAL3 | FAL2/FAL3 | **Sí** |
| `CAEP_RFC9396` | AAL2 | FAL1/FAL2/FAL3 | No |

`supports_backchannel` — activa flujos de logout/revocación vía backchannel (SAML SLO, OIDC BCLO).

### T-385 — auth_saga_catalog

Catálogo de flujos orquestados multi-paso. **12 sagas:**

`steps` (JSONB array): secuencia de nombres de pasos que el motor ejecuta en orden. El daemon lee esta columna para saber qué handlers invocar — sin código hardcodeado por flujo.

`is_emergency = TRUE` solo en `BREAKGLASS_EMERGENCY` — activa alertas SIEM automáticas.

`timeout_seconds`: tiempo máximo para completar el flujo (desde primer paso hasta token emitido).

### T-386 — auth_compliance_map

Mapa de cobertura normativa. **14 controles** de 5 estándares: NIST SP 800-63B-4, PCI DSS 4.0, OWASP ASVS 5.0, ISO 27001:2022, FIPS 140-3.

`method_codes[]` + `saga_codes[]` — lista de métodos y sagas que implementan el control.  
`coverage_level`: `FULL` / `PARTIAL` / `NOT_COVERED` — base para auditorías de compliance automáticas.

---

## S18 — Dispositivos (bauth)

**NIVEL 19 · Tablas:** T-390, T-391, T-392  
**Ref:** NIST SP 800-207 ZTA §4.2 · FIDO2 W3C L3 · OSDP v2.2 SIA · ISO/IEC 27001 A.6.2

### Arquitectura de dispositivos en ZTA

```
auth_device (T-390)          ← Registro central: lógico + FIDO2 HW + OSDP físico
      │
      ├── auth_device_posture (T-391)        ← Snapshot MDM/ZTA (TTL 4h)
      │                                           PDP verifica valid_until en cada request
      └── auth_device_credential_binding (T-392) ← WORM: qué credenciales viven en este dispositivo
```

### T-390 — auth_device

Registro central de tres tipos de dispositivos:

| `category` | `platform` | Caso de uso |
|-----------|-----------|-------------|
| `DESKTOP` / `MOBILE` / `TABLET` | WINDOWS/LINUX/MACOS/ANDROID/IOS | ZTA empresa |
| `SERVER` / `IOT` | LINUX/EMBEDDED | M2M/IoT/NHI |
| `SECURITY_KEY` / `SMART_CARD` | FIDO2_HW | YubiKey, PIV |
| `OSDP_READER` / `NFC_READER` | OSDP_HW | Lectores físicos OSDP v2.2 |

`aaguid` — AAGUID del autenticador FIDO2 (matching con allowList de attestation).  
`trust_level` — evaluado por el PDP: `TRUSTED` / `CONDITIONALLY_TRUSTED` / `UNTRUSTED` / `QUARANTINE`.  
`is_osdp + osdp_address + osdp_version` — para lectores de acceso físico (torniquetes, puertas).

**Dispositivo sin usuario:** `user_id = NULL` es válido para M2M, IoT, lectores físicos.

### T-391 — auth_device_posture

Snapshot de postura MDM/ZTA. **TTL 4 horas** (`valid_until`).

El PDP verifica `valid_until > now()` antes de aceptar el device signal. Si expiró → dispositivo tratado como `UNKNOWN` → aplica política más restrictiva (NIST SP 800-207 §3.3.1).

`risk_score` (0–100) es consumido por el PIP de riesgo del Motor de Políticas para el paso de scoring dinámico.

`posture_source`: `MDM` (Microsoft Intune/Jamf) · `EDR` (CrowdStrike/SentinelOne) · `AGENT` (agente SBOS) · `SELF_REPORTED` · `MANUAL`.

### T-392 — auth_device_credential_binding

WORM. `REVOKE UPDATE, DELETE FROM bauth_app_role`.

Binding M:N entre dispositivos (T-390) y credenciales (T-330). Permite:
- Al perder un dispositivo: `UPDATE auth_device SET status='LOST'` → job propaga revocación a todas las credenciales del binding.
- Audit trail inmutable: qué credencial estaba en qué dispositivo y desde cuándo.

`binding_type`:
- `FIDO2_RESIDENT` — passkey almacenada dentro del autenticador (no exportable)
- `FIDO2_CROSS_PLATFORM` — llave de hardware externa (YubiKey, etc.)
- `X509_MTLS` — certificado de dispositivo emitido por Vault PKI
- `SOFT_TOTP` — seed TOTP en dispositivo móvil
- `PUSH_NOTIFICATION` — token push para CIBA/bNotify
- `OSDP_CARD` — tarjeta física presentada al lector OSDP

---

## S19 — Context Plane (bos)

**NIVEL 20 · Tablas:** T-395..T-402  
**Archivo:** `bos_01__control_plane.sql` · **Schema:** `bos`  
**Ref:** NIST SP 800-207 §3.2 Policy Administrator · SBOS-049 Context Plane · ISO 27001:2022 A.9.4.2

### Arquitectura Context Plane — Policy Administrator (NIST SP 800-207)

```
REGISTRO PRE-AUTH                    SESIÓN POST-AUTH
─────────────────                    ─────────────────
bos.ctx_registered_device (T-395)        bos.ctx_context_session (T-396)
  dctx_id ←────────────── referencia ──→ dctx_id
  hostname, node_k8s, ip                 ctx_id (6 capas SBOS-049)
  state: PENDING                          entity_1_id, entity_2_id, entity_3_id, user_id
  TTL 8h                                  bitmask > 0, loa 1-4
  │                                       state: ACTIVE, TTL 12h
  │                                       traceparent (W3C)
  ├── bos.ctx_device_heartbeat (T-400)        │
  │     cada 30s, retención 24h           ├── bos.ctx_context_audit (T-397) WORM
  │                                       ├── bos.ctx_context_switch_log (T-398) WORM
  └── bos.ctx_context_policy (T-399)      ├── bos.ctx_context_transfer (T-401) WORM
        TTL, rate limit, MDM              └── bos.ctx_context_emergency (T-402) WORM
        por tenant                              control dual, TTL 2h, revisión 24h
```

### T-395 — bos.ctx_registered_device

Dispositivos registrados pre-autenticación. BitMask = 0 invariante. TTL 8h con heartbeat cada 30s. Se crea en `bos.ctx.device.register`; se promueve a `ctx_context_session` en login.

**FK:** `tenant_id → bauth.idn_tenant(tenant_id)`  
**Capa:** INFRAESTRUCTURA — complementa `bauth.auth_device` (T-390, capa de IDENTIDAD).

### T-396 — bos.ctx_context_session

Sesión de infraestructura post-auth. ctx_id de 6 capas (SBOS-049 §3.1). BitMask > 0 calculado por bAuth. Redis DB1 cachea para lookup O(1) < 1ms de Kong PEP. TTL 12h.

**FK:** `tenant_id → idn_tenant` · `entity_1/2/3_id + user_id → idn_identity_entity` · `dctx_id → bos.ctx_registered_device`  
**Complementa:** `bauth.ses_session_log` (T-181, capa de IDENTIDAD). 6 columnas únicas: entity_1/2/3_id, dctx_id, bitmask, traceparent.

### T-397 — bos.ctx_context_audit 🔒 WORM

Auditoría WORM de toda operación del Context Plane. Hash-chain SHA-256. Append-only. 16 tipos de operación. REVOKE UPDATE/DELETE.

### T-398 — bos.ctx_context_switch_log 🔒 WORM

Historial de cambios de contexto sin reautenticación. Detecta switches anómalos (movimiento lateral ITDR). REVOKE UPDATE/DELETE.

### T-399 — bos.ctx_context_policy

Políticas TTL y seguridad del Context Plane por tenant. Una fila por tenant (UNIQUE). Complementa `idn_tenant.session_ttl_max` (TTL identidad ≠ TTL infraestructura). Parámetros: device_ttl, session_ttl, heartbeat_interval, rate_limit_rps, require_mdm, auto_block_jailbreak.

### T-400 — bos.ctx_device_heartbeat

Heartbeats de dispositivos. Alta escritura (INSERT cada 30s por dispositivo). Retención 24h. Tabla separada de `registered_device` para evitar write amplification.

### T-401 — bos.ctx_context_transfer 🔒 WORM

Transferencia de contexto entre dispositivos. Tipos: USER_INITIATED, AUTO_CONTINUITY, ADMIN_TRANSFER, BREAKGLASS. REVOKE UPDATE/DELETE.

### T-402 — bos.ctx_context_emergency 🔒 WORM

Break-glass de contexto (D08-B04). Control dual NIST AC-17(3): quien activa ≠ quien aprueba. TTL máximo 2h fijo en DDL. Revisión post-hoc obligatoria en 24h. incident_ref externo obligatorio. REVOKE UPDATE/DELETE.

---

## S20 — BOS Control Plane (bos)

**NIVEL 21 · Tablas:** T-403..T-412  
**Archivo:** `bos_01__control_plane.sql` · **Schema:** `bos`  
**Ref:** ADR-021 (18-state machine) · ADR-040 (bootstrap) · RFC 6335 BCP 165 (Port Manager) · SBOS-BOS-CAP-001 · ISO 27001:2022 A.8.9/A.8.15/A.12.4

### Arquitectura BOS Control Plane — 6 grupos funcionales

```
GRUPO FCH — Motor ③ Server FICHAS
bos.fch_ficha_state (T-403)         ← Estado actual: 18 estados ADR-021
      └── bos.fch_ficha_event (T-404) 🔒  ← Historial WORM hash-chain SHA-256

GRUPO INS — Motor ① IAM Installer
bos.ins_bootstrap_event (T-405) 🔒  ← Bootstrap 6 capas (C-01..C-09) WORM
bos.ins_saga_execution (T-412)     ← Tracking mutable de sagas

GRUPO CAP — Motor ② SO Observable / Capacidad
bos.cap_sistema_snapshot (T-406)    ← 30+ métricas cada ~60s · PART mensual
bos.cap_tenant_policy (T-407)       ← Políticas por tenant · fallback a raíz

GRUPO PRT — Port Manager (A.12)
bos.prt_port_assignment (T-408)     ← Kardex RFC 6335 · inmutabilidad lógica

GRUPO REL — Release Plane
bos.rel_release_manifest (T-409)    ← Catálogo canary→early→stable Ed25519
bos.rel_release_event (T-410) 🔒   ← Historial WORM de actualizaciones

GRUPO WDG — Motor ② SO Observable / Watchdog
bos.wdg_watchdog_event (T-411) 🔒  ← Watchdog 3 capas: host|k8s|fichas
```

---

### Grupo FCH — Motor ③ Server FICHAS

#### T-403 — bos.fch_ficha_state

**Propósito:** Estado actual de cada ficha declarativa en la máquina de 18 estados (ADR-021). Una ficha = un componente de plataforma desacoplado de tenant. Multi-tenancy es un concepto de datos (discriminadores, RLS), no de infraestructura.

**¿Qué registra?** Una fila por ficha por servidor lógico: nombre, `server_id`, versión, estado de 18 posibles, categoría 1-5, backend (`bash|k8s|binary|python`), fechas de instalación y health check, hashes SHA-256 de los artefactos (drift detection).

**18 estados — CHECK constraint (ADR-021):**

| Grupo | Estados |
|-------|---------|
| Idle | `PENDING`, `READY`, `PAUSED`, `UNINSTALLED` |
| Instalación | `INSTALLING`, `INSTALLED`, `INSTALL_FAILED` |
| Actualización | `UPDATE_AVAILABLE`, `UPDATE_APPROVED`, `UPDATING`, `UPDATE_FAILED` |
| Salud | `DEGRADED`, `PHYSICAL_ERROR`, `LOGICAL_ERROR`, `REPAIRING`, `UNRECOVERABLE` |
| Ciclo de vida | `ROLLBACK`, `CLEANUP` |

**Clave natural:** `(ficha_name, server_id)` — una ficha por servidor. `hashes` JSONB contiene SHA-256 de `manifest.yml`, `yaml_engine.yml` y `task_catalog.sh` — base del drift detector.

**¿Cuándo se alimenta?** BOS Installer al instalar, actualizar, reparar o remover fichas. El daemon watchdog escribe `last_health_check_at` y `health_status` cada 30s.

**¿Necesita interfaz?** Sí — panel "Fichas" en `bosctl` (CLI) y JSON-RPC `bos.ficha.status`.

---

#### T-404 — bos.fch_ficha_event 🔒 WORM

**Propósito:** Historial WORM append-only de todos los cambios de estado de fichas. Cada transición de estado en T-403 genera una fila aquí. REVOKE UPDATE/DELETE. Hash-chain SHA-256 (`prev_hash`).

**¿Qué registra?** Por evento: ficha, tenant que lo disparó, actor y IP (NIST AU-3), operación, transición `from_state → to_state`, resultado (`OK|FAIL|PARTIAL|SKIPPED`), duración en ms, detalles JSONB, `saga_id` (agrupa todos los eventos de una saga completa).

**Diseño:** `tenant_id` es el tenant que DISPARÓ el evento (trazabilidad de auditoría), no un "dueño" de la ficha. FK a `fch_ficha_state` — una ficha debe existir antes de tener historial.

**Índice parcial:** `idx_fch_e_failures` — solo filas `result='FAIL'` para el panel de diagnóstico.

**¿Cuándo se alimenta?** Por el Installer en cada paso de saga. Nunca UPDATE o DELETE.

---

### Grupo INS — Motor ① IAM Installer

#### T-405 — bos.ins_bootstrap_event 🔒 WORM

**Propósito:** Registro WORM del bootstrap progresivo de 6 capas (C-01..C-09, ADR-040). Traza cada paso desde Ubuntu virgen hasta stack SBOS completo. Hash-chain SHA-256 por `bootstrap_run_id`.

**¿Qué registra?** Por paso: `bootstrap_run_id` (agrupa un intento completo), tenant, actor, nodo físico (`node_id` — NIST CM-8), capa 0-5, nombre de ficha, step, estado (`STARTED|COMPLETED|FAILED|SKIPPED|RETRYING`), código de verificación `C-NN`, resultado, detalles JSONB.

**Diseño de `tenant_id`:** NUNCA es NULL.
- Capas 0-2 (infraestructura): `tenant_id` = UUID del tenant raíz (sembrado en el seed de BD).
- Capas 3-5 (cliente): `tenant_id` = UUID del tenant que se instala.

**`verification_code`:** formato `C-01..C-09` — checkpoint de capa completada. NULL en steps intermedios. Índice parcial `idx_ins_be_vcode` para auditoría de checkpoints.

**¿Cuándo se alimenta?** Por `bos.installer.Bootstrap()` en cada paso. Nunca UPDATE o DELETE.

---

#### T-412 — bos.ins_saga_execution

**Propósito:** Tracking mutable de las sagas generales del IAM Installer (install, update, repair, remove, deploy_tenant, remove_tenant, suspend_tenant). A diferencia de T-405 (bootstrap WORM), esta tabla es mutable: el estado de la saga avanza de `RUNNING` a `COMPLETED|FAILED|COMPENSATING|COMPENSATED`.

**¿Qué registra?** Una fila por saga: tipo, estado actual, paso activo, `steps_completed` (array JSON con historial de pasos), `compensated_steps` (pasos que ya hicieron rollback), `started_at`, `completed_at`, `last_error`, `ctx_id`.

**Estados:** `RUNNING → COMPLETED | FAILED → COMPENSATING → COMPENSATED`

**Relación con T-404:** `fch_ficha_event.saga_id` referencia el `saga_id` de esta tabla — permite ver todos los eventos de ficha asociados a una saga.

**¿Cuándo se alimenta?** BOS escribe `RUNNING` al iniciar. Actualiza `steps_completed` en cada paso. En falla: transiciona a `COMPENSATING` y registra los pasos compensados.

---

### Grupo CAP — Motor ② SO Observable / Capacidad

#### T-406 — bos.cap_sistema_snapshot 📦 PART

**Propósito:** Instantáneas periódicas (~60s) de 30+ métricas del sistema para observabilidad continua y proyección de capacidad (Motor ② M5.1). **No es WORM** — es telemetría operativa con retención de 90 días.

**¿Qué registra?** Snapshot del sistema con 5 subsistemas:

| Subsistema | Métricas |
|-----------|----------|
| Context Plane | `ctx_sessions_active`, `ctx_devices_active` |
| Redis | `redis_memory_pct`, `redis_keys_count`, `redis_ops_per_sec` |
| PostgreSQL | `pg_connections_active/max`, `pg_db_size_bytes`, `pg_tps` |
| Kong | `kong_rps`, `kong_latency_p99_ms`, `kong_error_rate_pct` |
| bAuth | `bauth_cache_miss_pct`, `bauth_token_ops_sec` |
| bkernel | `bkernel_lag_ms`, `bkernel_events_sec` |
| K8s | `k8s_nodes_ready/total`, `k8s_pods_running/total`, CPU/mem `%` |
| Host | `host_cpu_pct`, `host_mem_pct`, `host_disk_pct`, `host_load_avg_1m` |
| Fichas | `units_healthy`, `units_degraded`, `units_error`, `units_total` |

**Particionamiento:** `PARTITION BY RANGE (captured_at)` — una partición mensual `bos.cap_sistema_snapshot_YYYY_MM`. BOS crea la del mes siguiente el día 25 (cron interno). Purga: `DROP TABLE` sobre particiones con rango terminado hace > 90 días (instantáneo).

**`scope`:** `GLOBAL` (tenant_id NULL) o `TENANT` (tenant_id NOT NULL) — constraint garantiza coherencia.

**¿Cuándo se alimenta?** El observador de capacidad escribe cada ~60s. El dashboard lee para gráficas de tendencia.

---

#### T-407 — bos.cap_tenant_policy

**Propósito:** Política de capacidad declarada por tenant (Motor ② M5.3). UNIQUE por tenant. Define umbrales de CPU/mem/disco, límites RPS de Kong, máximo de sesiones de contexto y horizon de proyección.

**Fallback:** Si un tenant no tiene fila, Motor M5.3 usa la fila del tenant raíz (sembrado en el seed de SBOS_db junto a la empresa master, sucursal master y política de capacidad raíz).

**`policy_mode`:**
- `autonomous` — BOS actúa automáticamente sin HITL
- `recommend` — BOS sugiere, humano aprueba
- `block_and_alert` — BOS bloquea nueva admisión y notifica
- `emergency` — protocolo completo de emergencia de capacidad

**Columnas clave:**
- `kong_tenant_rps_cap`: cap total de RPS del tenant en Kong PEP (infraestructura) — distinto de `ctx_context_policy.rate_limit_rps` (Context API) y de `bauth.idn_tenant.rate_limit_rps` (IAM).
- `ctx_sessions_max`: techo agregado del tenant (distinto de `max_sessions_per_user`).
- `projection_confidence` (0-1): confianza requerida para proyección de capacidad a N días.

**¿Cuándo se alimenta?** BOS seed al crear el tenant. El administrador actualiza via `bosctl` / `bos.cap.policy.update`. `updated_by + effective_from` → trazabilidad NIST AU-3.

---

### Grupo PRT — Port Manager (A.12)

#### T-408 — bos.prt_port_assignment

**Propósito:** Kardex de asignaciones de puertos — implementación interna de RFC 6335 (BCP 165) dentro de SBOS. Registro de inventario de activos de red conforme ISO 27001 A.8.20. **Inmutabilidad lógica:** las filas nunca se eliminan — solo transicionan `assigned → released → revoked`.

**¿Qué registra?** Por puerto: servicio, puerto (1-65535), protocolo (`TCP|UDP|SCTP|DCCP`), tipo (`HOST_PHYSICAL|HOST_LOGICAL|K8S_NODE_PORT|K8S_CLUSTER_IP|K8S_LOAD_BALANCER`), servidor lógico (`logical_server`), namespace K8s, ficha asignada (`ficha_id`), rol (`CONTROL_PLANE|DATA_PLANE|MANAGEMENT|DEBUG`), Cluster IP/External IP/DNS/Subdomain/Kong route, tipo de activo y propietario del activo, algoritmo de negociación (`algorithm`, default `'A'`), estado (`assigned|released|revoked|conflict`), timestamps de asignación, liberación y última validación.

**UNIQUE:** `(port, port_type, namespace)` — un puerto dentro del mismo espacio nunca puede estar asignado dos veces.

**¿Cuándo se alimenta?** BOS Port Manager (`bos.portman.assign` / `bos.portman.release`). El Motor verifica disponibilidad aquí en 3 capas antes de asignar cualquier puerto a una ficha.

**¿Necesita interfaz?** Sí — `bosctl port list`, `bosctl port lookup`, `bosctl port validate` (A.12 — Kardex de Puertos, A.15 §1).

**Implementado en:** `internal/portman/kardex.go` — `PgKardex` struct, commit `380cd69`.

---

### Grupo NET — Network Security Manager

#### T-413 — bos.net_cert_inventory

**Propósito:** Kardex de certificados TLS del entorno SBOS — ISO 27001:2022 A.8.24 (inventario de claves y certificados). Cubre todos los certificados: daemons en el host, fichas K8s, SVIDs SPIFFE/SPIRE y certs externos (Let's Encrypt). **Inmutabilidad lógica:** las filas nunca se eliminan — transicionan `active → expiring_soon → expired → revoked → superseded`.

**¿Qué registra?** Por certificado: CN, SAN[], emisor, número de serie RFC 5280 (`serial_number`, para OCSP), fingerprint SHA-256, vigencia (valid_from/valid_until), tipo (`daemon_host|ficha_k8s|spiffe_svid|external_wildcard|kong_tls|ca_internal`), algoritmo y tamaño de clave, servicio/namespace/ficha al que sirve, ruta en el host o nombre del Secret K8s, motor de emisión (`vault_pki|cert_manager|spire|acme_le|manual`), configuración de auto-renovación, `issued_at` (≠ `valid_from`), `last_renewed_at`, estado y ctx_id.

**UNIQUE:** `(fingerprint_sha256)` — un certificado con idéntico fingerprint no puede registrarse dos veces.

**days_remaining:** calculado en query como `EXTRACT(DAY FROM (valid_until - NOW()))::INTEGER` — `NOW()` no es IMMUTABLE, no puede usarse en `GENERATED ALWAYS AS STORED`.

**¿Cuándo se alimenta?** CERTMAN en `bos.certman.issue` / `bos.certman.revoke`. El watcher (`bos.certman.watch`) actualiza `last_checked_at` y cambia `status` a `expiring_soon` cuando `EXTRACT(DAY FROM (valid_until - NOW())) < renew_before_days`.

**¿Necesita interfaz?** Sí — `bosctl cert list --expiring-in 30`, `bosctl cert status`, `bosctl cert export` (A.15 §2.8, §3.7).

---

#### T-414 — bos.net_security_events (particionada)

**Propósito:** Log de eventos de seguridad de red de todos los motores NetMan — ISO 27001 A.8.21 / NIST SP 800-41. Alta escritura en producción (miles de eventos/día). **Particionado mensual** por `event_time` para retención de 90 días sin degradación de rendimiento.

**Fuentes:** `portman` (asignación/liberación de puertos) · `certman` (emisión/revocación de certs) · `fwman` (reglas/NetworkPolicy) · `ips` (bloqueos CrowdSec, fail2ban, psad) · `bos_daemon` (replay_detected, brute_force).

**¿Qué registra?** Por evento: tipo (ver CHECK), severidad (`info|warn|high|critical`), fuente, ficha/servicio/namespace afectados, IP origen (`INET` nativo PostgreSQL para búsquedas por red), puerto destino, detalles libres en JSONB y ctx_id.

**event_type:** `port_assigned|port_released|port_conflict|port_validated` · `cert_issued|cert_renewed|cert_expiring|cert_revoked` · `fw_rule_added|fw_rule_removed|netpol_synced|fw_drift_detected` · `ips_block|ips_unblock|port_scan_detected|crowdsec_ban|crowdsec_unban|fail2ban_ban|fail2ban_unban|ddos_detected|brute_force_detected|replay_detected`

**Retención:** El daemon BOS crea particiones mensuales y elimina las que superan 90 días (via cron K8s Job).

**¿Necesita interfaz?** Sí — `bosctl ips alerts --last 24h --severity high` (A.15 §4.4, §7.7).

---

### Grupo REL — Release Plane

#### T-409 — bos.rel_release_manifest

**Propósito:** Catálogo canónico de versiones disponibles para pull desde el SKULL Release Server. Un registro = una versión de un daemon en un canal. Solo pull — SBOS nunca empuja a este catálogo.

**Canales:** `canary → early → stable` (orden de promoción). Cada versión existe primero en `canary`, se promueve a `early` tras validación, y a `stable` para despliegue en producción.

**¿Qué registra?** Por versión: daemon, versión semver, canal, URL del artefacto, SHA-256 del artefacto, firma Ed25519 (verificada antes de desplegar), versión mínima de BOS requerida, release notes, flag `is_rollback_target` (versión validada a la que se puede hacer rollback), `pulled_at` (momento en que BOS descargó el manifiesto), `ctx_id`.

**UNIQUE:** `(daemon_name, version, channel)` — una versión en un canal es un registro único.

**Firma:** `signature_ed25519` — BOS verifica contra la clave pública del Release Server antes de aplicar cualquier actualización.

---

#### T-410 — bos.rel_release_event 🔒 WORM

**Propósito:** Historial WORM de cada operación de actualización o rollback de daemons. REVOKE UPDATE/DELETE. Una fila por operación (`INSTALL|UPDATE|ROLLBACK`) sobre un manifiesto.

**¿Qué registra?** Referencia al manifiesto (T-409), operación, estado (`STARTED|COMPLETED|FAILED|ROLLED_BACK`), quién lo disparó (`scheduler|watchdog|human`), daemon, versión, versión previa (`from_version`), error en caso de falla, actor y `ctx_id`.

**¿Cuándo se alimenta?** El Release Manager de BOS en cada ciclo de actualización. El Watchdog escribe cuando dispara un rollback automático (60s TTL).

---

### Grupo WDG — Motor ② SO Observable / Watchdog

#### T-411 — bos.wdg_watchdog_event 🔒 WORM

**Propósito:** Registro WORM de cada verificación del watchdog de 3 capas (Motor ②). Cada chequeo fallido o exitoso queda aquí con el resultado y la acción tomada. REVOKE UPDATE/DELETE.

**3 capas del watchdog (`check_layer`):**
- `ubuntu_host` — capa 1: systemd, servicios del OS, conectividad
- `k8s_cluster` — capa 2: pods, nodes, namespace health
- `bos_fichas` — capa 3: estado de fichas declarativas (T-403)

**`severity`:** `INFO | WARN | ERROR | CRITICAL`

**`action_taken`:**
- `auto_repair` — BOS inició reparación automática
- `hitl_escalated` — escalado a humano (HITL)
- `daemon_restart` — reinicio del daemon afectado
- `rollback` — rollback automático del Release Plane (60s TTL)
- `none` — verificación pasó, sin acción

**¿Cuándo se alimenta?** El watchdog corre cada 30s por capa. Cada resultado genera un evento aquí. `CHECK CRITICAL` + `action_taken='rollback'` → acompañado de fila en T-410.

---

## S20 — Biblioteca de Referencia (bauth)

**NIVEL 21 · Tablas:** T-999 · T-999b · T-999c  
**Archivo:** `SBOS_db_V2_DDL.sql`

> ⚠️ **LIBRERÍA DE REFERENCIA DOCUMENTAL — NO FUNCIONAL EN RUNTIME.**  
> Estas tablas **no participan en ningún flujo operacional de bAuth**: no intervienen en
> autenticación, evaluación de acceso, emisión de tokens ni ningún proceso del motor de
> identidad. Son datos de consulta estáticos que viven en SBOSDB como referencia.

**Consumidores válidos:**
- **Dashboard** — UI renderiza formularios, etiquetas y contexto normativo sin hardcodear texto
- **Agentes IA** — contexto normativo para búsqueda semántica (qex)
- **Programadores** — referencia durante el desarrollo de dominios y átomos

**NO consultar desde:** el motor de autenticación, el PDP, el PrivilegeEngine ni ningún componente de evaluación en runtime.

### T-999 — bauth.cfg_policy_library

**Propósito:** Árbol normalizado de las 16 fuentes normativas para consulta.  
**Estructura jerárquica:** `section → group → policy → config` con CTE recursivo desde `framework_raw` (T-999b).  
**16 fuentes normativas:** NIST SP 800-63B-4, FIDO2 CTAP 2.2, NIST PQC 2025, OAuth 2.1, Zero Trust NSA 2026, ISO 27001:2022, Industry Enterprise, PCI DSS 4.0, D3 Financiero, D4 Temporal, D6 Geo, D10 Delegación, CIS K8s 1.8, AWS IAM, SOC2 Type II.  
**13 dominios:** D1-D12 + SEC.  
**29 columnas:** `node_type`, `semantic_type`, `domain_map`, `source`, `standard_ref`, `compliance_ref`, `enforcement`, `risk_level`, `lifecycle`, `assurance_level`, `auth_factor`, `phishing_resistant`, `mfa_required`.  
**Contenido multilingüe:** `content` (original), `content_en` (inglés), `content_es` (español vía `translate_keys_en_es()`).  
**REVOKE UPDATE/DELETE** — inmutable en runtime.  
**Seed:** `DDLs/seeds/bauth_T999__cfg_policy_library.sql` — cargado por `inicializar_sbos_db.sh`.

### T-999b — bauth.framework_raw

**Propósito:** Staging de los 16 JSON normativos crudos sin transformar. Permite re-procesar T-999 actualizando solo las fuentes que cambiaron.

### T-999c — bauth.cfg_key_translation

**Propósito:** Diccionario de ~221 términos IAM inglés→español. Alimenta la función `translate_keys_en_es()` que genera `content_es` en T-999.

---

## Apéndice D — Normas y estándares aplicados

| Norma | Aplicación en SBOS_db_V2 |
|-------|--------------------------|
| **ISO/IEC 11179** | Documentación de columnas con nombre, tipo, significado, uso |
| **DAMA DMBOK v2** | Gestión del ciclo de vida de datos, lineage, calidad |
| **NIST RBAC N3 (INCITS 359)** | Modelo de roles, herencia DAG, SoD, closure table |
| **NIST SP 800-63B-4** | Políticas de contraseña, LoA/AAL 1-3, MFA, timeouts |
| **NIST SP 800-63A** | IAL1-3, verificación de identidad, atributos verificados |
| **NIST SP 800-53 Rev.5** | AC-2(7) access review, AC-5 SoD, AU-9 WORM, IA-3 NHI |
| **NIST SP 800-207** | Zero Trust Architecture, DomainRegistry, Policy Engine |
| **XACML 3.0** | PAP (árbol de políticas T-162), PDP, PEP, PIP (T-114/T-009) |
| **ISO 27001:2022** | A.5.15-18 access control, A.8.15 logging, A.8.22 PAM |
| **ISO 24760-2:2025** | Identity management reference architecture (D00) |
| **RFC 9562** | UUIDv7 como PK de todas las tablas |
| **RFC 8935/8936** | CAEP (T-191) y SSF delivery (T-192) |
| **RFC 9470** | Step-Up Authentication (T-181.step_up_valid_until) |
| **RFC 5545** | iCalendar (T-015 rrule, T-016 VALARM) |
| **BCP 47 / RFC 5646** | Tags de idioma (T-001) |
| **ISO 4217** | Códigos de moneda (T-003) |
| **IANA TZ Database** | Zonas horarias (T-004) |
| **Ley 2492 Bolivia** | Retención de datos 7 años (idn_tenant.data_retention_days=2555) |
| **SIN RND 102100000011** | Facturación electrónica Bolivia (cal_fiscal_year) |
| **PCI DSS 4.0** | Seguridad de datos de pago (privilege_atom_audit hash-chain) |
| **NIST SP 800-63-4** | Tres capas: identity entity / subscriber account / authenticator (S13/S14) |
| **FIDO2 / W3C WebAuthn L3** | auth_credential_fido2 (T-332): sign_count, backup state, transports |
| **RFC 9449 (DPoP)** | fed_token_issued (T-367): dpop_jkt, sender-constrained tokens |
| **RFC 8705 (mTLS)** | fed_client (T-365), auth_credential_x509 (T-333): certificate-bound tokens |
| **RFC 3161** | sig_timestamp (T-355): timestamps calificados |
| **RFC 6962** | blk_merkle_batch/leaf (T-359/360): árbol Merkle para anclaje |
| **FAPI 2.0** | fed_client (T-365): perfiles BASELINE / ADVANCED / FAPI2 |
| **W3C VCDM 2.0** | idn_identity_vc (T-167), wallet_item (T-381): Verifiable Credentials |
| **OID4VP / OpenID4VCI** | wallet_presentation_log (T-382), wallet_issuance_log (T-383) |
| **eIDAS 2.0** | wallet (T-380): EUDI Wallet soberana; T-382: verifiable verifier §5.3 |
| **GDPR Art. 7.3 + Art. 35** | wallet_presentation_log (WORM auditaría consentimiento), T-188 DPIA |
| **Ley 164 Bolivia** | sig_key/sig_operation_log (D13): validez jurídica firma electrónica |
| **ADSIB-FD-POLT-015 v2.3** | sig_adsib_lifecycle (T-356): ciclo vida cert. calificado, 4 reemisiones |

---

---

## Historial de versiones

| Versión | Fecha | Cambios |
|---------|-------|---------|
| v2.13.0 | 2026-07-31 | T-408: columna `algorithm TEXT DEFAULT 'A'` (antes almacenado en `notes` como hack). T-413: `days_remaining` eliminado como `GENERATED ALWAYS AS` — `NOW()` no es IMMUTABLE; se calcula en query. T-413: añadidos `serial_number`, `issued_at`, `last_renewed_at`, `revocation_reason`; `kong_tls` agregado a cert_type CHECK. Todos los documentos (A.15, 3.08, A.65.02) sincronizados. VPS SBOSDB aplicado. |
| v2.12.0 | 2026-07-31 | T-408 `prt_port_assignment`: corrección CHECK `port_type` — valores alineados con código Go (`HOST_PHYSICAL\|HOST_LOGICAL\|K8S_NODE_PORT\|K8S_CLUSTER_IP\|K8S_LOAD_BALANCER`). T-413 `net_cert_inventory`: Kardex de certificados TLS (ISO 27001 A.8.24). T-414 `net_security_events`: log de eventos de seguridad de red (ISO 27001 A.8.21), particionado mensual por `event_time`, 27 event_types, src_ip tipo INET. Total schema `bos`: 20 tablas · 8 WORM · 8 grupos. |
| v2.11.0 | 2026-07-31 | S20 BOS Control Plane (`bos`): T-403..T-412. 10 tablas nuevas (4 WORM) — FCH 18-state machine, INS bootstrap/sagas, CAP snapshots/policies, PRT port kardex, REL release plane, WDG watchdog 3 capas. Total schema `bos`: 18 tablas · 8 WORM · 7 grupos. |
| v2.12.0 | 2026-07-31 | Cierre de gaps D09/D11/D14/D15: T-364 `idn_credencial_revocacion`, T-368 `idn_credencial_introspeccion`, T-460 `pam_cuenta_privilegiada`, columnas rotación NHI en T-189, VIEW `mv_audit_dashboard`. 3 tablas + 1 VIEW. |
| v2.11.0 | 2026-07-31 | T-999 `cfg_policy_library`: biblioteca de referencia. 16 fuentes, 13 dominios, 29 columnas. REVOKE UPDATE/DELETE. |
| v2.10.0 | 2026-07-30 | S19 Context Plane (`bos`): T-395..402. 8 tablas (4 WORM hash-chain) — Policy Administrator NIST SP 800-207. Schema `bos` autónomo en `bos_01__control_plane.sql`. Cierra GAP D08-B04. |
| v2.9.0 | 2026-07-30 | T-384..386 (catálogos MethodRegistry: protocolos, sagas, compliance) + S18 Dispositivos T-390..392 (ZTA/MDM/FIDO2/OSDP). 6 tablas + 34 seeds. |
| v2.8.0 | 2026-07-30 | S13..S17 + D12 implementados: +T-320..322 (Usuarios NIST 800-63-4), +T-330..338 (Autenticación MethodRegistry FIDO2/X.509/DPoP), +T-350..357 (Firma Digital D13 Ley 164), +T-358..362 (Blockchain Merkle/Besu/Arbitrum), +T-365..367 (Federación OIDC DPoP FAPI2), +T-380..383 (Billetera Digital EUDI OID4VP). 32 nuevas tablas. 106 tablas base + 17 particiones hijas = 123 CREATE TABLE. |
| v2.7.0 | 2026-07-28 | GAP-D00-01..10 implementados: +T-186 (lifecycle_event JML), +T-169 (did_document), +T-187 (scim_attribute_map), +T-188 (dpia_registro); ALTER T-157 +5 cols clasificación; ALTER T-159 +risk_threshold +dirm_policy_ref; ALTER T-165 +risk_context +eidas_level; ALTER T-166 +6 cols GDPR granular; ALTER T-167 +eidas_assurance_level +eidas_vc_type; seeds mDL/VC (T-159) + seeds bdomain (T-159) |
| v2.6.0 | 2026-07-28 | T-165..T-168 implementadas (proofing, consentimiento, VC, FAL); 25 átomos D00 (pos 292-316); triggers trg_iiattr_history, trg_iip_status_to_entity, trg_ivc_expiry_check; jobs fn_job_reproofing_check/vc_expiry_check/next_partition + OS crontab |
| v2.5.0 | 2026-07-25 | T-158 (idn_identity_attribute_history) WORM hash-chain + 6 particiones mensuales |
| v2.4.0 | 2026-07-24 | T-159 (idn_identity_requirement) implementada |
| v2.3.0 | 2026-07-22 | S8-S12 refactorizados; nombres canónicos del DDL |

*Fin del manual — SBOS_db_V2_DDL_MANUAL.md — v2.11.0 · 2026-07-31*
