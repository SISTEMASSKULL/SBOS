# BAUTH-INVENTARIO-TABLAS-DECISION.md — Inventario Final con Líneas de Código

**Versión:** 7.0 · **Fecha:** 2026-06-25 · **Estado:** ✅ COMPLETADO
**DDL:** `BauthAgent/db/migrations/DDL_skSBOS_db.sql` · **Líneas totales:** ~5000
**VPS:** 13.140.128.230 · **DB test:** `bauth_test` · **Errores DDL:** 0
**Tablas totales:** 177 (160 bauth + 8 bglobal + 9 bcalendar)

---

## D1 — LÓGICO (Fast-Path) — 24 tablas

| Línea | Tabla | Origen | Propósito | Seed |
|:---:|-------|--------|----------|:---:|
| 2514 | `privilege_domain` | Existente | Catálogo de 12 dominios de soberanía D1-D12 | ✅ |
| 2551 | `privilege_verb` | Existente | Vocabulario de 50 verbos (CRUD + SAP ACTVT + extendidos) | ✅ |
| 2527 | `privilege_application` | Existente | 12 aplicaciones registradas en el ecosistema SBOS | ✅ |
| 2541 | `privilege_group` | Existente | 48 grupos funcionales por aplicación | ✅ |
| 2585 | `privilege_atom` | Existente | 5,808 átomos (app × grupo × dominio × verbo) | ✅ |
| 2606 | `privilege_role` | Existente | Roles definidos por tenant (runtime) | — |
| 2623 | `privilege_role_atom` | Existente | Rol BitMask relacional (one-hot encoding) | — |
| 2665 | `privilege_atom_policy` | Existente | 3,216 políticas JSONB encadenadas a átomos | ✅ |
| 2696 | `privilege_atom_audit` | Existente | Registro WORM de cada evaluación de acceso | — |
| 2487 | `log_zone` | Existente | 29 zonas organizacionales | ✅ |
| 2564 | `bos_permiso_logico` | Existente | Permisos lógicos: zona × verbo × rol | — |
| 2786 | `zone_application_map` | Migrada | Zonas → Apps con módulos y scopes OAuth 2.0 | ✅ |
| 4127 | `zone_field_restriction` | Nueva | Campos ocultos/solo-lectura por zona y app | — |
| 4147 | `zone_button_rule` | Nueva | Reglas de botones con PYSON, users_required, SoD | — |
| 4170 | `zone_record_rule` | Nueva | Filtros SQL por zona. Scope GLOBAL/REGIONAL/BRANCH | — |
| 4190 | `zone_data_policy` | Nueva | Políticas de datos: clasificación, PII, masking, GDPR | — |
| 4493 | `tryton_action_visibility` | Nueva | Acciones/menús visibles en Tryton por zona | — |
| 2396 | `idn_role_template` | Existente | Template JSONB del rol (14 secciones) | ✅ |
| 2825 | `idn_role_closure` | Migrada | Closure table DAG herencia H-RBAC | — |
| — | `idn_role_d1` | Nueva | Roles pre-configurados D1: OPERADOR_CAJA, GERENTE_REGIONAL... | 🔴 |

## D2 — FÍSICO (Fast-Path) — 10 tablas

| Línea | Tabla | Origen | Propósito | Seed |
|:---:|-------|--------|----------|:---:|
| 1873 | `fis_location` | Existente | Ubicaciones físicas jerárquicas con coordenadas POINT | — |
| 1923 | `fis_location_closure` | Existente | Closure table jerarquía de ubicaciones | — |
| 2066 | `fis_access_zone` | Existente | Zonas de acceso físico con nivel de seguridad | — |
| 2088 | `fis_zone_member` | Existente | Puente zona ↔ location (N:M) | — |
| 1996 | `fis_device` | Existente | Dispositivos OSDP/ONVIF/MQTT: lectores, cámaras, chapas | — |
| 1967 | `fis_area_config` | Existente | Reglas de seguridad por área: escolta, 2 personas, mantrap | — |
| 2035 | `fis_controller` | Existente | Controladoras físicas OSDP | — |
| 4331 | `fis_zone_method_requirement` | Nueva | Métodos requeridos por nivel de zona física | — |
| 4347 | `fis_emergency_config` | Nueva | Emergencia: FIRE→UNLOCK, SECURITY_BREACH→LOCKDOWN | — |
| 4293 | `idn_role_d2` | Nueva | Roles D2: EMPLEADO_STANDARD, VISITANTE, TECNICO | 🔴 |

## D3 — FINANCIERO (Policy-Path) — 10 tablas

| Línea | Tabla | Origen | Propósito | Seed |
|:---:|-------|--------|----------|:---:|
| 2118 | `fin_transaction_type` | Existente | 20 tipos de transacción + controls JSONB (SIN, dual-control) | ✅ |
| 2148 | `fin_limit` | Existente | Límites financieros por tenant/rol con JSONB flexible | — |
| 2183 | `fin_approval_chain` | Existente | Cadena de aprobación con timeout y escalación | — |
| 2201 | `fin_approval_level` | Existente | Niveles: amount_up_to, approvers_required, approver_roles | — |
| 2233 | `fin_approval` | Existente | Registro de aprobaciones individuales | — |
| 2263 | `fin_document_operation` | Existente | Operaciones documentos fiscales: emitir, cancelar, exportar SIN | — |
| 2285 | `fin_role_permission` | Existente | Permisos financieros por rol | — |
| 2856 | `fin_sod_rule` | Migrada | Matriz SoD formal: pares incompatibles con rationale (SOX §404) | ✅ |
| 2902 | `fin_decision_matrix` | Migrada | Matriz decisión en cascada 3 niveles por tipo y monto | — |
| 4293 | `idn_role_d3` | Nueva | Roles D3: CAJERO, APROBADOR_N1, APROBADOR_N2 | 🔴 |

## D4 — TEMPORAL (Policy-Path) — 11 tablas

| Línea | Tabla | Origen | Propósito | Seed |
|:---:|-------|--------|----------|:---:|
| 1676 | `cal_calendar` (bcal) | Existente | Colecciones RFC 4791: WORK, FISCAL, PROCESS, COMPLIANCE | ✅ |
| 1707 | `cal_event` (bcal) | Existente | Eventos RFC 5545 VEVENT con rrule sin expandir | — |
| 1744 | `cal_alarm` (bcal) | Existente | Alarmas RFC 5545 VALARM | — |
| 1775 | `cal_notification_log` (bcal) | Existente | Log WORM notificaciones. Solo INSERT | — |
| 1803 | `cal_holiday` (bcal) | Existente | Feriados fijos y móviles. Pascua por fórmula Gauss | ✅ |
| 1829 | `cal_schedule` (bcal) | Existente | Horarios RFC 7953 VAVAILABILITY con shifts JSONB | ✅ |
| 1555 | `cal_fiscal_year` (bcal) | Existente | Años fiscales: OPEN→CLOSED→ARCHIVED | — |
| 1644 | `idn_calendar_assignment` | Existente | Asignación calendarios a tenant/empresa/sucursal | — |
| 4363 | `cal_overtime_policy` (bcal) | Nueva | Horas extra: max día/semana, tasa, aprobación | — |
| 4382 | `cal_break_policy` (bcal) | Nueva | Descansos: almuerzo, breaks, auto-logout | — |
| 4293 | `idn_role_d4` | Nueva | Roles D4: HORARIO_OFICINA, TURNO_ROTATIVO, GUARDIA_24X7 | 🔴 |

## D5 — BIOMÉTRICO + IDENTITY HUB — 9 tablas

| Línea | Tabla | Origen | Propósito | Seed |
|:---:|-------|--------|----------|:---:|
| 4293 | `idn_role_d5` | Nueva | Roles D5: BIOMETRICO_HUELLA, FACIAL, SIN_BIOMETRIA, PASSKEY_EXTERNO | 🔴 |
| 4638 | `user_client_device` | Nueva | Dispositivo cliente (celular/tablet/desktop) vinculado al usuario | 🔴 |
| 4724 | `mobile_heartbeat_log` | Nueva | Latidos 30s del dispositivo. Offline detection | 🔴 |
| 4747 | `idp_client` | Nueva | Apps externas OIDC/SAML/OAuth2. bAuth como IdP | 🔴 |
| 4776 | `idp_client_policy` | Nueva | Políticas auth por cliente externo: métodos biométricos, AAL | 🔴 |
| 4799 | `idp_token_config` | Nueva | Config tokens JWT/opaque: claims, firma, DPoP | 🔴 |
| 4882 | `external_session_registry` | Nueva | Sesiones apps externas vinculadas al ctx_id | 🔴 |
| 4911 | `mobile_app_config` | Nueva | Config remota app: versión mínima, endpoints, cert pins | ✅ |
| 4932 | `device_attestation_log` | Nueva | Play Integrity / App Attest verificaciones. Score | — |

## D6 — GEOESPACIAL (External) — 8 tablas

| Línea | Tabla | Origen | Propósito | Seed |
|:---:|-------|--------|----------|:---:|
| 294 | `global_country` (bgl) | Existente | 196 países ISO 3166-1 + UN M.49 | ✅ |
| 494 | `geo_timezone` (bgl) | Existente | 319 zonas IANA TZ con coordenadas POINT | ✅ |
| 4515 | `geo_trust_tier` | Nueva | Tiers confianza ubicación (BeyondCorp): HIGH/MEDIUM/LOW | ✅ |
| 4537 | `geo_velocity_policy` | Nueva | Viaje imposible >900 km/h. Tolerancia GPS 10 km | 🔴 |
| 4557 | `geo_fence` | Nueva | Geo-cercas: polígono o punto+radio por sucursal | — |
| 4580 | `geo_location_log` | Nueva | Ubicaciones de login: (lat,lon) + fuente + precisión | — |
| 4602 | `geo_evaluation_log` | Nueva | Resultado evaluación geo: país, fence, velocidad, trust | — |
| 4293 | `idn_role_d6` | Nueva | Roles D6: LOCAL_BOLIVIA, REGIONAL_LATAM, GLOBAL | 🔴 |

## D7 — RED (External) — 5 tablas

| Línea | Tabla | Origen | Propósito | Seed |
|:---:|-------|--------|----------|:---:|
| 1496 | `idn_tenant_network` | Existente | CIDRs, gateways, DNS y redes autorizadas por tenant | — |
| 4012 | `net_device` | Migrada | Dispositivos red: tipo, serial, firmware, IP, MAC | — |
| 4401 | `net_ztna_policy` | Nueva | ZTNA: default DENY, allowed_services explícitos | — |
| 4974 | `certificate_pin_config` | Nueva | Public Key Pins SHA-256. Anti-MITM CA comprometida | 🔴 |
| 4293 | `idn_role_d7` | Nueva | Roles D7: CORPORATIVO, VPN, REMOTO_SEGURO | 🔴 |

## D8 — CONTEXTO (Pre-BitMask) — 8 tablas

| Línea | Tabla | Origen | Propósito | Seed |
|:---:|-------|--------|----------|:---:|
| 2961 | `ses_context` | Migrada | Sesiones ctx_id 6-capas SBOS-049 + W3C traceparent | — |
| 3027 | `ses_context_switch` | Migrada | Historial cambios de contexto operativo | — |
| 3063 | `ses_superuser_context` | Migrada | Break-glass SU. Sesión 4h max. Vault 2-of-3 | — |
| 4418 | `ses_risk_policy` | Nueva | Riesgo sesión tiempo real: factores, thresholds, acciones | — |
| 4445 | `ses_caep_config` | Nueva | OpenID CAEP 1.0: session-revoked, credential-change | — |
| 4680 | `ctx_transfer_log` | Nueva | Transferencias ctx_id vía QR/NFC/BLE/WebSocket | 🔴 |
| 4704 | `qr_challenge_registry` | Nueva | Challenges QR. Anti-replay. TTL 120s | 🔴 |
| 4825 | `emergency_override_policy` | Nueva | Override temporal geo/horario/zonas. Supervisor | 🔴 |
| 4853 | `visitor_access_policy` | Nueva | Acceso visitantes: puertas, horarios, ambientes | 🔴 |
| 4293 | `idn_role_d8` | Nueva | Roles D8: SESION_8H, EXTENDIDA, BREAK_GLASS | 🔴 |

## D9 — CREDENCIALES (Pre-BitMask) — 46 tablas

| Línea | Tabla | Origen | Propósito | Seed |
|:---:|-------|--------|----------|:---:|
| 2361 | `ath_method` | Existente | 32 métodos auth + domain_classification | ✅ |
| 2344 | `ath_policy` | Existente | 5 políticas legacy (borrado — usar ath_policy_d*) | ❌ |
| 2309 | `ath_config` | Existente | 4 configuraciones legacy (borrado — usar ath_config_d*) | ❌ |
| 3102 | `ath_credential_policy` | Migrada | 8 políticas de credenciales: PASSWORD, TOTP, WEBAUTHN, X509, OAUTH, API_KEY, ENCRYPTION, SIGNING | ✅ |
| 3135 | `ath_password_history` | Migrada | Historial passwords Argon2id. Trigger auto-limpieza | — |
| 3153 | `ath_password_screening` | Migrada | Cribado HIBP k-anonymity. NIST 800-63B-4 §5.1.1.2 | — |
| 3171 | `ath_mfa_enrollment` | Migrada | Dispositivos MFA: TOTP, WebAuthn, Passkeys, Recovery Codes | — |
| 3196 | `ath_recovery_method` | Migrada | 6 tipos recuperación verificados. NIST 800-63B-4 §4.4 | — |
| 3219 | `ath_recovery_challenge` | Migrada | Preguntas hash Argon2id + salt 32B. Bloqueo 3 intentos | — |
| 3240 | `ath_binding` | Migrada | Vínculo authenticator↔subscriber. LoA 1-4. NIST §5.2.1 | — |
| 3268 | `ath_revocation` | Migrada | Revocaciones WORM authenticators. <30s | — |
| 3287 | `ath_login_attempt` | Migrada | Intentos login particionado × mes. Bloqueo progresivo | — |
| 3315 | `ath_consent` | Migrada | Consentimientos GDPR: data_processing, biometric, cookies | — |
| 3338 | `ath_rotation_log` | Migrada | Auditoría rotación credenciales: quién, cuándo, por qué | — |
| 3363 | `ath_token_delivery` | Migrada | Trazabilidad entrega tokens: canal, receptor, testigo | — |
| 3384 | `ath_enrollment_log` | Migrada | Enrolamiento 5 pasos: verify→generate→deliver→verify→activate | — |
| 3404 | `ath_federation_protocol` | Migrada | 16 protocolos federación con rfc_ref | ✅ |
| 4067 | `ath_auth_flow` | Nueva | 8 flujos compuestos auth: standard, elevated, hardware... | ✅ |
| 4087 | `ath_auth_flow_method` | Nueva | Métodos × orden × obligatoriedad por flujo (N:M) | ✅ |
| 4102 | `ath_step_up_rule` | Nueva | 8 reglas RFC 9470: trigger, condition, loa, acr_value | ✅ |
| 4222 | `ath_policy_d1` | Nueva | Políticas D1: record_rules, scope, field_rules | ✅ |
| 4222 | `ath_policy_d2` | Nueva | Políticas D2: anti_passback, escort, two_person, mantrap | ✅ |
| 4222 | `ath_policy_d3` | Nueva | Políticas D3: dual_approval, sod, limits | ✅ |
| 4222 | `ath_policy_d4` | Nueva | Políticas D4: schedules, holidays, overtime, breaks | ✅ |
| 4222 | `ath_policy_d5` | Nueva | Políticas D5: liveness, fmr, enrollment, gdpr | ✅ |
| 4222 | `ath_policy_d6` | Nueva | Políticas D6: geo_fence, velocity, trust_tiers | ✅ |
| 4222 | `ath_policy_d7` | Nueva | Políticas D7: device_trust, vpn, mtls, ztna | ✅ |
| 4222 | `ath_policy_d8` | Nueva | Políticas D8: ctx_id, session_ttl, reauth, caep | ✅ |
| 4222 | `ath_policy_d9` | Nueva | Políticas D9: password, mfa, recovery, lockout, phishing | ✅ |
| 4222 | `ath_policy_d10` | Nueva | Políticas D10: max_duration, non_delegable, chain | ✅ |
| 4222 | `ath_policy_d11` | Nueva | Políticas D11: retention, review_freq, hash_chain | ✅ |
| 4222 | `ath_policy_d12` | Nueva | Políticas D12: merkle, did, proof_types | ✅ |
| 4256 | `ath_config_d1` a `ath_config_d12` | Nuevas | 12 tablas de configs: solo d9 tiene seed real, resto 🔴 | 🟡 |
| 4293 | `idn_role_d9` | Nueva | Roles D9: AAL1_BASICO, AAL2_MFA, AAL3_HARDWARE, M2M_MTLS | ✅ |
| 4293 | `idn_role_d10` | Nueva | Roles D10: SIN_DELEGACION, DELEGACION_BASICA... | 🔴 |

## D10 — DELEGACIÓN — 1 tabla

| Línea | Tabla | Origen | Propósito | Seed |
|:---:|-------|--------|----------|:---:|
| 3437 | `dlg_delegation` | Migrada | Delegaciones temporales ≤21 días. Auto-revoke. NIST AC-5 | — |

## D11 — AUDITORÍA — 7 tablas

| Línea | Tabla | Origen | Propósito | Seed |
|:---:|-------|--------|----------|:---:|
| 3472 | `aud_event` | Migrada | WORM particionado × mes. Hash-chain SHA-256. 30 tipos evento | — |
| 3530 | `aud_review` | Migrada | Recertificación accesos. ISO 27001 A.9.2.5 | — |
| 3554 | `aud_ghost_account` | Migrada | Cuentas huérfanas: 5 tipos detección, risk score 0-100 | — |
| 3576 | `aud_policy_change` | Migrada | Cambios políticas WORM. old/new_params JSONB. ISO 27001 A.8.9 | — |
| 3595 | `aud_policy_version` | Migrada | Historial versionado políticas para rollback | — |
| 3612 | `aud_compliance_map` | Migrada | Mapa desde compliance_ref de cfg_policy_library. ISO+NIST+PCI+SOC+FIDO | ✅ |
| 4293 | `idn_role_d11` | Nueva | Roles D11: BASICO, COMPLETO, SOX_PCIDSS | 🔴 |

## D12 — BLOCKCHAIN — 6 tablas

| Línea | Tabla | Origen | Propósito | Seed |
|:---:|-------|--------|----------|:---:|
| 3680 | `blk_anchor` | Migrada | Anclajes L2 (Arbitrum One): tx_hash, gas, costo USD | — |
| 3703 | `blk_merkle_batch` | Migrada | Lotes Merkle cada 1h. Status: open→sealed→anchored | — |
| 3729 | `blk_merkle_leaf` | Migrada | Hojas Merkle con proof verificable independiente | — |
| 3747 | `blk_account` | Migrada | Cuentas on-chain × tenant. Variante B | — |
| 3767 | `blk_reconciliation` | Migrada | Verificación cross-chain: merkle_root DB vs on-chain | — |
| 4293 | `idn_role_d12` | Nueva | Roles D12: SIN_ANCLAJE, ANCLAJE_MERKLE, DID_BASICO | 🔴 |

## D13 — SYNC — 1 tabla

| Línea | Tabla | Origen | Propósito | Seed |
|:---:|-------|--------|----------|:---:|
| 3638 | `sync_log` | Migrada | WORM sync bAuth→KC+Tryton. Solo INSERT+SELECT | — |

## D14 — SoD — 2 tablas

| Línea | Tabla | Origen | Propósito | Seed |
|:---:|-------|--------|----------|:---:|
| 4462 | `sod_validation_config` | Nueva | Frecuencia y scope validación SoD. Auto-remediación | — |
| 4477 | `conflict_interest_policy` | Nueva | Entidades restringidas, grados relación, declaraciones | — |

## USER — 2 tablas

| Línea | Tabla | Origen | Propósito | Seed |
|:---:|-------|--------|----------|:---:|
| 3787 | `idn_user_template` | Migrada | Template SCIM 2.0 desde cfg_policy_library: métodos, sesiones, credenciales, AAL | ✅ |
| 3824 | `idn_user_role` | Migrada | Asignación roles→usuarios con trazabilidad y vigencia | — |

## ORG — 3 tablas

| Línea | Tabla | Origen | Propósito | Seed |
|:---:|-------|--------|----------|:---:|
| 3849 | `org_empresa` | Migrada | Empresa: razón social, NIT, régimen fiscal, idiomas, timezones | ✅ |
| 3877 | `org_sucursal` | Migrada | Sucursal: dirección, horario, coordenadas POINT | ✅ |
| 3905 | `org_pos_logico` | Migrada | POS SIN Bolivia: dosificación, CUIS, rango facturas, contador | — |

## SEC — 3 tablas

| Línea | Tabla | Origen | Propósito | Seed |
|:---:|-------|--------|----------|:---:|
| 3942 | `sec_key_inventory` | Migrada | Inventario 20 tipos llaves criptográficas. NIST SP 800-57 | — |
| 3967 | `sec_key_rotation` | Migrada | Ciclo vida claves: GENERATED/ROTATED/REVOKED/COMPROMISED | — |
| 3990 | `sec_key_recovery` | Migrada | Recuperación llaves: break-glass, admin reset, desastre | — |

## TENANT — 7 tablas

| Línea | Tabla | Origen | Propósito | Seed |
|:---:|-------|--------|----------|:---:|
| 644 | `idn_tenant` | Existente | Registro central tenant: 7 estados, soft-delete, compliance | ✅ |
| 903 | `idn_tenant_currencies` | Existente | Monedas activas por tenant | ✅ |
| 952 | `idn_tenant_languages` | Existente | Idiomas activos por tenant | ✅ |
| 1075 | `idn_tenant_verification` | Existente | Verificación multi-paso tenant | — |
| 1166 | `idn_tenant_config` | Existente | Config JSONB: token TTL, rate limits, features | — |
| 1349 | `idn_tenant_domain` | Existente | Dominios web verificados con certificado SSL | — |
| 1496 | `idn_tenant_network` | Existente | CIDRs, gateways, DNS, tipo de red | — |

## GLOBAL (bglobal) — 8 tablas

| Línea | Tabla | Origen | Propósito | Seed |
|:---:|-------|--------|----------|:---:|
| 130 | `global_language` (bgl) | Existente | 125 idiomas ISO 639-3 + CLDR 46 | ✅ |
| 294 | `global_country` (bgl) | Existente | 196 países ISO 3166-1 + UN M.49 | ✅ |
| 387 | `global_currency` (bgl) | Existente | 45 monedas ISO 4217 | ✅ |
| 494 | `geo_timezone` (bgl) | Existente | 319 zonas IANA TZ con POINT | ✅ |
| 4041 | `global_config` (bgl) | Migrada | Parámetros centrales. NIST SP 800-53 CM-6 | — |
| 2740 | `menu_item` (bgl) | Migrada | 41 ítems menú jerárquicos (3 niveles) | ✅ |
| 2759 | `menu_context` (bgl) | Migrada | Entradas contexto: dropdowns, ENUMs, widgets UI | ✅ |
| 2769 | `menu_item_atom` (bgl) | Migrada | Vinculación menú ↔ átomo con LoA mínimo | — |

## INFRAESTRUCTURA — 3 tablas

| Línea | Tabla | Origen | Propósito | Seed |
|:---:|-------|--------|----------|:---:|
| 2325 | `bos_crypto_algorithm` | Existente | 16 algoritmos criptográficos. FIPS 140-3/203/204/205 | — |
| 2447 | `idn_tier_policy` | Existente | 9 tiers con LoA, MFA, sesiones, auditoría | ✅ |
| 2470 | `bos_rol_template_history` | Existente | WORM historial cambios templates. Hash-chain SHA-256 | — |

---

## CFG — BIBLIOTECA DE POLÍTICAS — 2 tablas + 2 funciones

| Línea | Tabla | Origen | Propósito | Seed |
|:---:|-------|--------|----------|:---:|
| — | `cfg_policy_library` | Nueva | Biblioteca unificada: 9,140 políticas/configs/métodos. 16 fuentes, 13 dominios, 29 columnas, 15 índices, FK autoreferencial | ✅ |
| — | `cfg_key_translation` | Nueva | Mapeo 221 claves JSON inglés→español para traducción recursiva | ✅ |
| — | `jsonb_explode(jsonb)` | Nueva | Función PL/pgSQL: descompone objetos (jsonb_each) y arrays (jsonb_array_elements) para CTE recursivo | — |
| — | `translate_keys_en_es(jsonb)` | Nueva | Función PL/pgSQL: recorre JSONB recursivamente y traduce claves usando cfg_key_translation. Valores preservados intactos | — |

## RESUMEN FINAL

| Esquema | Tablas |
|---------|:---:|
| `bauth` | 162 |
| `bglobal` | 8 |
| `bcalendar` | 9 |
| **TOTAL** | **179** |

| Indicador | Valor |
|-----------|:---:|
| Errores DDL | 0 |
| Seeds creados | 55+ |
| Idempotencia ×3 | 0 errores, mismo resultado |
| Dominios cubiertos | 12 de 12 |
| Fases completadas | 5 de 5 |
| Líneas DDL | ~5000 |

---

*Documento v7.1. 179 tablas + 2 funciones con línea de referencia. Incluye cfg_policy_library (biblioteca unificada 9,140 políticas/configs).*
