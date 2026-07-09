# BAUTH — Inventario de Políticas, Configuraciones y Rules
**Fecha:** 2026-07-07 · **Fuente:** VPS 13.140.128.230 · `SBOS_db` schema `bauth`

---

## Resumen ejecutivo

| Artefacto | Tabla | Total |
|---|---|---|
| Biblioteca maestra | `cfg_policy_library` | **9,184** registros · 21 fuentes · 12 dominios |
| Políticas activas | `ath_policy_d1..d12` | **884** políticas |
| Configuraciones activas | `ath_config_d1..d12` | **174** configuraciones |
| Reglas de step-up | `ath_step_up_rule` | **8** reglas |
| Reglas de validación | `cfg_validation_rule` | **260** reglas |
| Reglas SoD financiero | `fin_sod_rule` | **6** reglas |
| Políticas de tier | `idn_tier_policy` | **9** tiers |

---

## 1. Políticas por dominio (`ath_policy_dN`)

### Totales por dominio

| Dom | Nombre | Propias | LIB-* | **Total** | Configs |
|---|---|---:|---:|---:|---:|
| D1 | Lógico (RBAC/ABAC) | 6 | 42 | **48** | 14 |
| D2 | Físico (acceso físico) | 7 | 87 | **94** | 14 |
| D3 | Financiero | 9 | 15 | **24** | 20 |
| D4 | Temporal (horarios) | 5 | 15 | **20** | 16 |
| D5 | Biométrico | 10 | 6 | **16** | 9 |
| D6 | Geoespacial | 6 | 10 | **16** | 20 |
| D7 | Red / Zero Trust | 6 | 296 | **302** | 20 |
| D8 | Contexto (sesión) | 5 | 47 | **52** | 13 |
| D9 | Credenciales / MFA | 16 | 79 | **95** | 10 |
| D10 | Delegación | 4 | 14 | **18** | 18 |
| D11 | Auditoría | 4 | 164 | **168** | 20 |
| D12 | Blockchain | 6 | 25 | **31** | 0 |
| **TOTAL** | | **84** | **800** | **884** | **174** |

> **LIB-*** = sincronizadas desde `cfg_policy_library` vía `bauth_43__framework_sync.sql`  
> **Propias** = políticas operacionales específicas del sistema (no derivadas de JSON)

---

### D1 — Lógico (políticas propias)

| Código | Nombre | Normas |
|---|---|---|
| `DATA_CLASS_INTERNAL` | Clasificación: INTERNAL | NIST 800-53 AC-3 |
| `HIDE_FINANCIAL_FIELDS` | Ocultar campos financieros | NIST 800-53 AC-3 |
| `MAX_RECORDS_200` | Máximo 200 registros por consulta | NIST 800-53 AC-6 |
| `RECORD_RULE_REGION` | Regla de registro: región | ANSI INCITS 359-2004 |
| `SCOPE_BRANCH` | Scope: Sucursal | NIST 800-53 AC-3, ANSI INCITS 359-2004 |
| `SCOPE_REGIONAL` | Scope: Regional | NIST 800-53 AC-3 |

---

### D2 — Físico (políticas propias)

| Código | Nombre | Normas |
|---|---|---|
| `ANTI_PASSBACK_HARD` | Anti-Passback Estricto | IEC 60839-11-5, SIA OSDP v2.2.3 |
| `ANTI_PASSBACK_SOFT` | Anti-Passback Suave | IEC 60839-11-5 |
| `BIOMETRIC_ENROLLMENT_HYBRID` | Enrolamiento biométrico híbrido | ISO 30107-3, NIST SP 800-63B-4 §5.2.3 |
| `DURESS_CODE_ENABLED` | Código de coacción | IEC 60839-11-5, BS 5979 |
| `ESCORT_REQUIRED` | Escolta requerida para visitantes | ISO 27001 A.7.2, NIST SP 800-53 PE-3 |
| `MANTRAP_REQUIRED` | Esclusa de seguridad | IEC 60839-11-5, NIST SP 800-53 PE-3 |
| `TWO_PERSON_RULE` | Regla de dos personas | ISO 27001 A.7.1, NIST SP 800-53 PE-3 |

---

### D3 — Financiero (políticas propias)

| Código | Nombre | Normas |
|---|---|---|
| `APPROVAL_CHAIN_3_TIERS` | Cadena de aprobación 3 niveles | COSO 2013, SOX §404 |
| `DUAL_APPROVAL_ABOVE_5000` | Aprobación dual > 5.000 BOB | SOX §404, COSO 2013, NIST SP 800-53 AC-5 |
| `LIMIT_DAILY_10000` | Límite diario 10.000 BOB | PCI DSS 4.0.1 Req.7, COSO 2013 |
| `LIMIT_MONTHLY_50000` | Límite mensual 50.000 BOB | PCI DSS 4.0.1 Req.7 |
| `REQUIRE_SECURE_NETWORK` | Red segura obligatoria | PCI DSS 4.0.1 Req.7, NIST SP 800-207 ZTA |
| `SIN_COMPLIANCE_BOLIVIA` | Cumplimiento SIN Bolivia | SIN RND 102100000011, ISO 20022 |
| `SOD_CASHIER_RECONCILE` | SoD: Cajero ≠ Conciliador | SOX §404, COSO 2013 §8 |
| `SOD_CREATOR_APPROVER` | SoD: Creador ≠ Aprobador | SOX §404, NIST SP 800-53 AC-5, COBIT 2019 |
| `TRANSACTION_SCHEDULE_OFFICE` | Horario de transacciones: oficina | PCI DSS 4.0.1 Req.7 |

---

### D4 — Temporal (políticas propias)

| Código | Nombre | Normas |
|---|---|---|
| `BREAK_LUNCH_60MIN` | Almuerzo 60 minutos | Ley General del Trabajo Bolivia |
| `OVERTIME_MAX_4H` | Horas extra máx 4h/día | Ley General del Trabajo Bolivia |
| `SCHEDULE_24X7` | Acceso 24×7 | RFC 5545 |
| `SCHEDULE_OFFICE_HOURS` | Horario de oficina Lun-Vie 8–18 | RFC 5545, ISO 8601 |
| `SESSION_TIMEOUT_8H` | Sesión máxima 8 horas | NIST SP 800-63B-4 §7 |

---

### D5 — Biométrico (políticas propias)

| Código | Nombre | Normas |
|---|---|---|
| `BIOMETRIC_ALTERNATIVE_REQUIRED` | Alternativa no biométrica obligatoria | NIST SP 800-63B-4 §5.2.3, NIST SP 800-63A-4 §5.1 |
| `BIOMETRIC_FMR_1_10000` | FMR 1:10,000 — AAL2 | NIST SP 800-63B-4 §5.2.3 |
| `BIOMETRIC_FMR_1_100000` | FMR 1:100,000 — AAL3 | NIST SP 800-63B-4 §5.2.3, IEC 60839-11-5 |
| `BIOMETRIC_GDPR_CONSENT` | Consentimiento explícito GDPR Art.9 | GDPR Art.9, Art.17, ISO 27701:2019, ISO/IEC 24745:2022 |
| `BIOMETRIC_LIVENESS_PASSIVE` | Liveness pasiva obligatoria | ISO/IEC 30107-3:2023, NIST SP 800-63B-4 §5.2.3 |
| `BIOMETRIC_MULTIMODAL_OPTIONAL` | Multi-biométrico opcional — AAL3 reforzado | NIST SP 800-63B-4 §5.2.3, ISO/IEC 30107-3:2023 §4.3 |
| `BIOMETRIC_QUALITY_MINIMUM` | Calidad mínima de muestra | ISO/IEC 29794-1:2024, NIST IR 8382, ISO/IEC 29794-4:2017 |
| `BIOMETRIC_RETENTION_LIMIT` | Retención y borrado de datos biométricos | GDPR Art.5, Art.17, ISO 27001:2022 A.8.10, NIST SP 800-88r2 |
| `BIOMETRIC_SPOOFING_MANDATORY_AAL3` | PAD obligatorio Level 2 — AAL3 | ISO/IEC 30107-3:2023, NIST SP 800-63B-4 §5.2.3 |
| `BIOMETRIC_TEMPLATE_REVOCATION` | Revocación de plantilla en < 30 s | ISO/IEC 24745:2022, NIST SP 800-53 Rev.5 AC-2(2), GDPR Art.17 |

---

### D6 — Geoespacial (políticas propias)

| Código | Nombre | Normas |
|---|---|---|
| `COUNTRY_RESTRICT_BO` | Restricción geográfica Bolivia | ISO 3166-1 |
| `GDPR_DATA_RESIDENCY` | Residencia de datos EEA | GDPR Art.44-49, NIS 2 |
| `GEOFENCE_REQUIRED` | Geo-fence obligatorio | NIST SP 800-53 PE-3, Google BeyondCorp |
| `OFAC_SANCTIONS_BLOCK` | Bloqueo OFAC | OFAC, SWIFT KYC |
| `TRUST_TIER_EVALUATION` | Evaluación de trust tier | Google BeyondCorp |
| `VELOCITY_CHECK_900KMH` | Viaje imposible > 900 km/h | NIST SP 800-63B-4, Google BeyondCorp |

---

### D7 — Red / Zero Trust (políticas propias)

| Código | Nombre | Normas |
|---|---|---|
| `API_RATE_LIMIT_PER_CLIENT` | Rate limiting por cliente | OAuth 2.1 BCP, RFC 6585 |
| `CONTINUOUS_VERIFICATION_5MIN` | Verificación continua cada 5 min | NIST SP 800-207, OpenID CAEP 1.0 |
| `DEVICE_TRUST_MIN_70` | Trust score mínimo 70 | NIST SP 800-207 ZTA, CISA ZTMM v2 |
| `MTLS_REQUIRED_M2M` | mTLS obligatorio M2M | RFC 8705, OAuth 2.1 BCP |
| `VPN_REQUIRED_REMOTE` | VPN obligatoria acceso remoto | NIST SP 800-207 ZTA |
| `ZTNA_DEFAULT_DENY` | Zero Trust default deny | NIST SP 800-207, CISA ZTMM v2 |

---

### D8 — Contexto / Sesión (políticas propias)

| Código | Nombre | Normas |
|---|---|---|
| `CAEP_SESSION_REVOKED` | CAEP: session-revoked | OpenID CAEP 1.0 |
| `CONTEXT_SWITCH_AUDIT` | Auditar cambio de contexto | SBOS-049 §5, ISO 27001 A.8.15 |
| `CTX_ID_REQUIRED` | ctx_id obligatorio | SBOS-049, W3C Trace Context |
| `REAUTH_4H` | Reautenticación cada 4 h | NIST SP 800-63B-4 §7.2 |
| `SESSION_TTL_8H` | Sesión 8 horas | NIST SP 800-63B-4 §7 |

---

### D9 — Credenciales / MFA (políticas propias)

| Código | Nombre | Normas |
|---|---|---|
| `LOCKOUT_PROGRESSIVE` | Bloqueo progresivo | NIST SP 800-53 AC-7, OWASP ASVS V2.1.2, PCI DSS 4.0 Req 8.3.4 |
| `MFA_AAL2_REQUIRED` | MFA obligatorio AAL2 | NIST SP 800-63B-4 §4.2, FIDO2 Level 2 |
| `MFA_AAL3_HARDWARE` | MFA AAL3 Hardware Device-Bound | NIST SP 800-63B-4 §4.3, FIPS 140-3 |
| `MFA_STEPUP_RFC9470` | Step-Up RFC 9470 | RFC 9470, NIST SP 800-63B-4 §4.3 |
| `PR_PHISH_FIDO2` | Phishing-Resistant AAL2+ | NIST SP 800-63B-4 Final §4.2, FIDO2 Level 3 |
| `PWD_ARGON2ID` | Hash Argon2id obligatorio | OWASP ASVS V2.4.3, NIST SP 800-63B-4 §5.1.1.2 |
| `PWD_BLOCKLIST` | Lista de bloqueo de passwords comunes | NIST SP 800-63B-4 §5.1.1.2, OWASP ASVS V2.1.2 |
| `PWD_HIBP_CHECK` | Verificación HIBP obligatoria | NIST SP 800-63B-4 §5.1.1.2, OWASP ASVS V2.1.7 |
| `PWD_HISTORY_5` | Historial de 5 passwords | OWASP ASVS V2.1.6 |
| `PWD_MIN_LENGTH_12` | Longitud mínima 12 caracteres | NIST SP 800-63B-4 §5.1.1.2, OWASP ASVS V2.1.1 |
| `PWD_NO_COMPLEXITY` | Sin reglas de complejidad | NIST SP 800-63B-4 §5.1.1.2 |
| `PWD_NO_ROTATION` | Sin rotación periódica forzada | NIST SP 800-63B-4 §5.1.1.2 |
| `RECOVERY_BACKUP_CODES` | Códigos de respaldo | OWASP ASVS V2.5.1 |
| `RECOVERY_MFA` | Recuperación con MFA | OWASP ASVS V2.5.1, NIST SP 800-63B-4 §4.4 |
| `SESSION_CONCURRENT_1` | Una sesión concurrente | NIST SP 800-63B-4 §7 |
| `SESSION_TIMEOUT_8H` | Timeout de sesión 8 h | NIST SP 800-63B-4 §7, OWASP ASVS V3.3 |

---

### D10 — Delegación (políticas propias)

| Código | Nombre | Normas |
|---|---|---|
| `DELEGATION_APPROVAL_REQUIRED` | Aprobación requerida | ISO 27001 A.8.2, NIST SP 800-53 AC-5 |
| `DELEGATION_MAX_7D` | Delegación máxima 7 días | NIST SP 800-53 AC-5, ANSI INCITS 359-2004 DSD |
| `DELEGATION_NON_TRANSFERABLE` | Permisos no delegables | ISO 27001 A.8.2 |
| `DELEGATION_NO_CHAIN` | Sin re-delegación | NIST SP 800-53 AC-5 |

---

### D11 — Auditoría (políticas propias)

| Código | Nombre | Normas |
|---|---|---|
| `AUDIT_RETENTION_7Y` | Retención 7 años | SOX §404, PCI DSS 10.3.2, ISO 27001 A.8.15 |
| `AUDIT_RETENTION_90D` | Retención 90 días | ISO 27001 A.8.15 |
| `HASH_CHAIN_SHA256` | Hash-chain SHA-256 | PCI DSS 10.3.2, NIST SP 800-53 AU-3 |
| `REVIEW_QUARTERLY` | Revisión trimestral de accesos | ISO 27001 A.9.2.5, NIST SP 800-53 AC-2 |

---

### D12 — Blockchain (políticas propias)

| Código | Nombre | Normas |
|---|---|---|
| `DID_VC_SIGNED` | Credenciales Verificables | W3C VC 1.0, ERC-735 |
| `DID_W3C_REGISTRY` | Identidad Descentralizada W3C | W3C DID Core 1.0, ERC-725 |
| `MERKLE_ANCHOR_HOURLY` | Anclaje Merkle cada hora | NIST IR 8202 |
| `MERKLE_PROOF_VERIFIABLE` | Proof verificable independiente | NIST IR 8202 |
| `SMART_CONTRACT_AUDIT` | Auditoría de Smart Contracts | EIP-712, ISO 27001 A.8.15 |
| `TX_VALIDATE_CONSENSUS` | Validación por consenso IBFT | NIST IR 8202 |

---

## 2. Configuraciones por dominio (`ath_config_dN`)

Estructura de columnas: `config_key · config_value (JSONB) · description · standard_ref[]`

| Dominio | Configuraciones activas |
|---|---:|
| D1 — Lógico | 14 |
| D2 — Físico | 14 |
| D3 — Financiero | 20 |
| D4 — Temporal | 16 |
| D5 — Biométrico | 9 |
| D6 — Geoespacial | 20 |
| D7 — Red | 20 |
| D8 — Contexto | 13 |
| D9 — Credenciales | 10 |
| D10 — Delegación | 18 |
| D11 — Auditoría | 20 |
| D12 — Blockchain | 0 |
| **TOTAL** | **174** |

> D12 sin configuraciones — pendiente seed `ath_config_d12`.

---

## 3. Rules (`ath_step_up_rule` — 8 reglas)

Todas requieren **AAL3 + reautenticación**. Trigger → evento que las activa.

| Código | Trigger | AAL requerido | Descripción |
|---|---|---|---|
| `STEP-CLOSE-CASH` | `close_cash_register` | 3 | Cierre de caja — trazabilidad completa de arqueo |
| `STEP-DATA-EXPORT` | `bulk_data_export` | 3 | Exportación masiva (> 100 registros) — prevención de exfiltración |
| `STEP-DELEGATION` | `delegation_create` | 3 | Crear delegación de permisos + aprobación del gerente |
| `STEP-FIN-APPROVE` | `financial_approve` | 3 | Aprobación financiera sobre límite del rol (últimos 5 min) |
| `STEP-SOD-OVERRIDE` | `sod_override` | 3 | Override de SoD — hardware key + justificación + aprobación dual |
| `STEP-SYSTEM-CONFIG` | `system_config_change` | 3 | Cambio de configuración del sistema — 0 segundos de antigüedad |
| `STEP-USER-MGMT` | `user_role_assignment` | 3 | Asignar/modificar roles privilegiados — trazabilidad completa |
| `STEP-VOID-INVOICE` | `void_invoice` | 3 | Anulación de factura — prevención de fraude fiscal |

---

## 4. Rules (`cfg_validation_rule` — 260 reglas)

Reglas de validación estructurada de datos por dominio y categoría.  
Categorías: `ENUM` (valores permitidos) · `RANGE` (rangos numéricos) · `TYPE` (tipo de dato)

| Dominio | ENUM | RANGE | TYPE | **Total** | Severidad error |
|---|---:|---:|---:|---:|---:|
| ALL (transversal) | 8 | — | 1 | 9 | 4 |
| COMP (compliance) | 2 | 6 | 2 | 10 | 10 |
| D1 — Lógico | 4 | 7 | 5 | 16 | 15 |
| D2 — Físico | 1 | 6 | 1 | 8 | 8 |
| D3 — Financiero | 4 | 14 | — | 18 | 18 |
| D4 — Temporal | — | 19 | 1 | 20 | 19 |
| D5 — Biométrico | 1 | 10 | 1 | 12 | 12 |
| D6 — Geoespacial | — | 5 | — | 5 | 5 |
| D7 — Red | 2 | 18 | — | 20 | 20 |
| D8 — Contexto | 1 | 12 | — | 13 | 13 |
| D9 — Credenciales | 14 | 41 | 3 | 58 | 58 |
| D10 — Delegación | — | 5 | 1 | 6 | 6 |
| D11 — Auditoría | 2 | 13 | 3 | 18 | 18 |
| D12 — Blockchain | — | 4 | — | 4 | 4 |
| SEC (seguridad gral) | 6 | 34 | 3 | 43 | 43 |
| **TOTAL** | **45** | **194** | **21** | **260** | **253** |

> D9 Credenciales concentra el 22% de las reglas de validación (58/260) — refleja la complejidad de políticas de contraseñas y MFA según NIST SP 800-63B-4.

---

## 5. Rules (`fin_sod_rule` — 6 reglas de Separación de Funciones)

Controles SoD financiero. Acción `BLOCK` = deniega la operación. `COMPENSATE` = requiere control adicional.

| Posición A | Posición B | Riesgo | Acción | Fundamento normativo |
|---|---|---|---|---|
| 14 (FINANCIAL_CREATE) | 15 (FINANCIAL_APPROVE) | ALTO | BLOCK | SOX §404 · COSO Control Activities: quien crea no aprueba |
| 15 (FINANCIAL_APPROVE) | 14 (FINANCIAL_CREATE) | ALTO | BLOCK | SOX §404: par simétrico (dual control forzoso) |
| 101 (emisión facturas) | 102 (registro cobros) | ALTO | BLOCK | COSO 2013 §7: previene desfalco por facturación falsa + auto-cobro |
| 201 (órdenes compra) | 202 (aprobación pagos) | ALTO | BLOCK | COSO 2013 §8: previene colusión con proveedores |
| 401 (auditoría) | 101 (permisos operativos) | ALTO | BLOCK | IIA Standard 1100: independencia obligatoria de auditoría interna |
| 301 (nómina) | 302 (datos maestros empleados) | MEDIO | COMPENSATE | COSO 2013 §9: requiere aprobación dual como control compensatorio |

---

## 6. Políticas de tier de identidad (`idn_tier_policy` — 9 tiers)

Define métodos MFA, timeouts de sesión y nivel de aseguramiento por tier de usuario.

| Tier | Nombre | AAL | MFA requerido | Métodos permitidos | Timeout sesión | Intentos fallidos |
|---|---|---|---|---|---|---|
| `SU` | Superusuario PAM | AAL3 | Sí | FIDO2, WebAuthn | 4 h | 0 (sin bloqueo automático) |
| `BIZ_N1` | Admin Plataforma | AAL3 | Sí | FIDO2, WebAuthn, TOTP | 8 h | 0 |
| `BIZ_N2` | Dirección | AAL2 | Sí | WebAuthn, TOTP | 8 h | 3 |
| `BIZ_N3` | Gerencia / Supervisión | AAL2 | Sí | TOTP, WebAuthn | 8 h | 3 |
| `BIZ_N4` | Operativo Calificado | AAL2 | No | TOTP | 8 h | 3 |
| `BIZ_N5` | Operativo / Soporte | AAL2 | No | TOTP | 8 h | 2 |
| `M2M` | Service Accounts | M2M | No | ClientCredentials, mTLS | 24 h | 0 |
| `EXT_N0` | Cliente Externo | AAL1 | No | Password, Social | 4 h | 5 |
| `VISITANTE` | Visitante Temporal | AAL1 | No | Email OTP | 1 h | 1 |

---

## 7. Biblioteca maestra (`cfg_policy_library`) — distribución por dominio

| Dom | Nombre | Políticas (`policy`) | Configs (`config`) | Secciones | **Total registros** |
|---|---|---:|---:|---:|---:|
| D1 | Lógico | 42 | 250 | 1 | 420 |
| D2 | Físico | 87 | 783 | 1 | 1,305 |
| D3 | Financiero | 15 | 61 | 1 | 98 |
| D4 | Temporal | 15 | 68 | 1 | 99 |
| D5 | Biométrico | 6 | 40 | — | 66 |
| D6 | Geoespacial | 10 | 67 | 1 | 106 |
| D7 | Red | 296 | 2,612 | 6 | 4,406 |
| D8 | Contexto | 47 | 298 | — | 514 |
| D9 | Credenciales | 79 | 713 | 7 | 1,114 |
| D10 | Delegación | 14 | 74 | 1 | 106 |
| D11 | Auditoría | 164 | 1,461 | 3 | 2,428 |
| D12 | Blockchain | 25 | 100 | — | 179 |
| SEC* | Seguridad gral | 28 | 269 | 1 | 447 |

> *`SEC` = registros que no calificaron en ningún dominio específico durante la clasificación. Aún útiles como referencia normativa general.

---

## Apéndice — Tablas de rules vacías (pendientes de seed)

Las siguientes tablas de reglas existen en schema `bauth` pero tienen 0 registros:

| Tabla | Propósito |
|---|---|
| `zone_button_rule` | Visibilidad de botones Tryton por zona/rol |
| `zone_data_policy` | Políticas de datos por zona organizacional |
| `zone_record_rule` | Reglas de registros Tryton (ir.rule SQL) |
| `net_ztna_policy` | Políticas ZTNA por segmento de red |
| `geo_velocity_policy` | Políticas de velocidad geográfica por tier |
| `ses_risk_policy` | Políticas de riesgo de sesión contextual |
| `visitor_access_policy` | Políticas de acceso para visitantes |
| `emergency_override_policy` | Políticas de break-glass / emergencia |
| `conflict_interest_policy` | Políticas de conflicto de interés |

> Estas tablas son parte del modelo pero requieren seeds operacionales para poblarlas.

---

## 9. Análisis de tablas vacías — qué son y estado de CRUD

### Grupo 1 — Reglas de enforcement por zona (`zone_*`)

Estas tres tablas son **propias de bAuth** — definen cómo el motor de autorización de bAuth responde cuando evalúa el acceso de un usuario según su zona lógica. bAuth las consulta directamente en tiempo de evaluación; no hay sincronización externa.

| Tabla | Qué es |
|---|---|
| `zone_button_rule` | Define qué acciones están habilitadas por zona, modelo de datos y aplicación. bAuth las evalúa al emitir el JWT para determinar qué permisos de acción incluye en el token. |
| `zone_data_policy` | Define la clasificación de datos por zona: si la zona puede acceder a PII, PHI, datos GDPR-sensibles, cuántos días retiene, qué política de enmascaramiento aplica. bAuth la consulta en el PEP al validar acceso a recursos sensibles. |
| `zone_record_rule` | Define el scope de registros que un usuario de esa zona puede ver (`BRANCH`, `REGIONAL`, `GLOBAL`). bAuth incluye el scope en el JWT como claim; la aplicación destino aplica el filtro. |

Son **tablas de configuración del motor PEP de bAuth** — sin ellas, el motor evalúa acceso sin restricción de zona.

---

### Grupo 2 — Políticas singleton de motor de evaluación

Cada una es el **parámetro global de un motor específico**. No son listas — son una sola fila activa por sistema:

| Tabla | Qué es | Motor que la consume |
|---|---|---|
| `net_ztna_policy` | El interruptor global ZTNA: acción por defecto (`DENY`), servicios permitidos, si microsegmentación está activa, intervalo de re-verificación. | PrivilegeEngine D7 |
| `geo_velocity_policy` | Umbrales del detector de impossible travel: velocidad máxima (900 km/h), tolerancia, ventana de tiempo, acción al detectar violación (`REQUIRE_STEP_UP` / `TERMINATE_SESSION`). | GeoEngine D6 |
| `ses_risk_policy` | Los 4 umbrales de riesgo de sesión (0–30 bajo, 30–60 medio, 60–80 alto, 80–95 crítico) y la acción de cada nivel. | SessionRiskEngine D8 |
| `conflict_interest_policy` | Política global de conflicto de interés: grados de relación restringidos, frecuencia de declaración anual, método de verificación. | ComplianceEngine D10/D3 |

---

### Grupo 3 — Registros operacionales de ciclo de vida

No son configuración — son **registros que se crean y revocan durante la operación del sistema**:

| Tabla | Qué es |
|---|---|
| `visitor_access_policy` | Un registro por cada visita autorizada. El host crea el registro, define zonas permitidas, ventana de validez y vincula el QR del visitante. Se revoca al salir o al expirar. Tiene FK a `qr_challenge_registry`. |
| `emergency_override_policy` | Un registro por cada break-glass activo. Un superusuario autoriza el bypass temporal de restricciones geo/temporales para un usuario específico, con ticket de referencia. Se revoca manualmente o al expirar. Tiene FK a `qr_challenge_registry`. |

---

### Estado de CRUD planificado

| Tabla | Estado en catálogo atómico |
|---|---|
| `zone_button_rule` | Mencionada en sincronización Tryton (`BAUTH-CRUD-ROLES-USUARIOS.md` capa `ir.model.button`) — **sin handler JSON-RPC propio definido** |
| `zone_data_policy` | Mencionada como output del sync Tryton — **sin handler JSON-RPC propio definido** |
| `zone_record_rule` | Mencionada como output del sync Tryton capa `ir.rule` — **sin handler JSON-RPC propio definido** |
| `ses_risk_policy` | Marcada como **"absorbida por átomos REGLA + RiskEngine"** (`BAUTH-ARQUITECTURA-ATOMICA-FINAL.md` línea 771) — sin CRUD propio en diseño actual |
| `net_ztna_policy` | Aparece en árbol de señales de confianza — **sin átomo ni handler asignado** |
| `geo_velocity_policy` | Diseñada como átomo `D6.bauth.geo.geo_velocity_max_kmh` en `privilege_atom` — **conflicto de diseño no resuelto** entre tabla directa vs átomo de rol |
| `visitor_access_policy` | **Sin planificación**. Tabla y FK a `qr_challenge_registry` existen, flujo de creación/revocación no está en ningún documento |
| `emergency_override_policy` | **Sin planificación**. Tabla y FK a `qr_challenge_registry` existen, flujo break-glass no está en ningún documento de handlers |
| `conflict_interest_policy` | **Sin planificación**. Singleton sin handler ni seed definido |

---

### Tres trabajos pendientes clasificados

**Trabajo 1 — Seeds de singletons** (simples, 1 INSERT cada uno):
- `net_ztna_policy` — valores ZTNA canónicos (default DENY, microsegmentación, verificación 300 s)
- `geo_velocity_policy` — impossible travel 900 km/h, tolerancia 10 km, ventana 5 min, on_violation = REQUIRE_STEP_UP
- `ses_risk_policy` — umbrales 30/60/80/95, acciones NONE/REQUIRE_STEP_UP/REQUIRE_STEP_UP/TERMINATE_SESSION
- `conflict_interest_policy` — 2 grados, declaración ANNUAL, verificación COMPLIANCE_REVIEW

**Trabajo 2 — Seeds de zona** (requieren `log_zone` y `privilege_application` pobladas primero):
- `zone_button_rule` — botones por zona y modelo Tryton
- `zone_data_policy` — clasificación de datos por zona
- `zone_record_rule` — filtros SQL por zona y scope

**Trabajo 3 — Handlers JSON-RPC** (flujos operacionales completos con estados):
- `visitor_access_policy`: métodos `bauth.visitor.create`, `bauth.visitor.revoke`, `bauth.visitor.list_active`
- `emergency_override_policy`: métodos `bauth.emergency.open`, `bauth.emergency.close`, `bauth.emergency.audit`
- Ambos necesitan diseño de átomo, validaciones de negocio y registro de estado (`ACTIVE` → `EXPIRED`/`REVOKED`)

---

## 10. Representación gráfica de flujos CRUD por grupo

---

### Grupo 1 — Tablas `zone_*` (configuración del motor PEP de bAuth)

El administrador configura las reglas de zona directamente en bAuth.
bAuth las evalúa en tiempo real al emitir tokens y validar accesos.
No hay sincronización externa — bAuth es el dueño y evaluador.

```
 ADMINISTRADOR (BIZ_N1 — AAL3)
      │
      │  bauth.zone.configure(zone_id, app_code, model, rules)
      ▼
┌─────────────────────────────────────────────────────┐
│                   bAuth JSON-RPC                     │
│                                                      │
│  1. Validar que zone_id existe en log_zone           │
│  2. Validar que app_code existe en                   │
│     privilege_application                            │
│  3. Validar model_name contra catálogo interno       │
│  4. Registrar cambio en aud_policy_change            │
└──────────────┬──────────────────────────────────────┘
               │
       ┌───────┼───────────────┐
       ▼       ▼               ▼
  zone_        zone_           zone_
  button_rule  record_rule     data_policy
  ─────────    ───────────     ───────────
  INSERT /     INSERT /        INSERT /
  UPDATE       UPDATE          UPDATE
  ON CONFLICT  ON CONFLICT     ON CONFLICT
  (zone_id,    (zone_id,       (zone_id)
   app_code,    app_code,      DO UPDATE
   model_name,  model_name)    SET pii_access,
   button_name) DO UPDATE       masking_policy,
  DO UPDATE     SET domain_json, retention_days
  SET condition, scope
      step_up_loa

       bAuth PEP los consulta en cada evaluación de acceso:
       ┌─────────────────────────────────────────┐
       │  Usuario presenta token  →  bAuth PEP   │
       │  ¿qué acciones tiene en zone X?          │
       │    → leer zone_button_rule               │
       │  ¿qué scope de registros?                │
       │    → leer zone_record_rule               │
       │  ¿puede acceder a campo PII?             │
       │    → leer zone_data_policy               │
       │  Resultado incluido en claims del JWT    │
       └─────────────────────────────────────────┘
```

**Estados posibles de una regla de zona:**

```
                     CREAR
                       │
                       ▼
                  ┌─────────┐
                  │ ACTIVA  │◄──── UPDATE (admin ajusta parámetros)
                  │is_active│
                  │  = true │
                  └────┬────┘
                       │
              admin desactiva zona
                       │
                       ▼
                  ┌─────────┐
                  │INACTIVA │  (is_active = false)
                  │         │  Tryton deja de aplicar la regla
                  └─────────┘
```

---

### Grupo 2 — Singletons de motor (una fila activa, solo UPDATE)

Estas tablas nunca se crean en operación — se insertan en el seed inicial
y solo se actualizan cuando un superusuario cambia los parámetros del motor.

```
 SUPERUSUARIO (tier SU — AAL3 obligatorio)
      │
      │  bauth.config.update_engine_policy(engine, params)
      ▼
┌─────────────────────────────────────────────────────┐
│                   bAuth JSON-RPC                     │
│                                                      │
│  1. Verificar AAL3 fresco (step-up STEP-SYSTEM-      │
│     CONFIG ya activado)                              │
│  2. Validar parámetros contra cfg_validation_rule    │
│  3. Registrar cambio en aud_policy_change            │
└──────────────┬──────────────────────────────────────┘
               │
    ┌──────────┼──────────────────┐
    ▼          ▼                  ▼                  ▼
net_ztna_  geo_velocity_    ses_risk_       conflict_interest_
policy     policy           policy          policy
──────────  ─────────────   ──────────      ──────────────────
UPDATE      UPDATE           UPDATE          UPDATE
WHERE       WHERE            WHERE           WHERE
is_active   is_active        is_active       is_active
= true      = true           = true          = true
               │
               ▼
   Motor correspondiente lee la fila en
   cada ciclo de evaluación (no hay caché
   — siempre lee el valor vigente)
```

**No hay DELETE ni INSERT en operación:**

```
  seed inicial          operación normal         nunca
  ─────────────         ────────────────         ──────
  INSERT (1 fila)  →    UPDATE parámetros   →    DELETE
                        + audit trail            (solo
                                                 desactivar)
```

**Flujo de actualización con audit trail:**

```
  UPDATE motor_policy
       │
       ├──► aud_policy_change  (qué cambió, quién, cuándo, ctx_id)
       ├──► aud_policy_version (snapshot del valor anterior)
       └──► notificación al motor (canal Redis Streams vía bkernel)
                │
                ▼
          Motor recarga
          configuración
          en < 1 s
```

---

### Grupo 3 — Registros operacionales (`visitor_access_policy`)

Ciclo de vida completo: el anfitrión crea la visita, se genera un QR,
el visitante entra, y al salir (o al vencer el tiempo) el registro se revoca.

```
 ANFITRIÓN (empleado con permiso D2.visitor.host)
      │
      │  bauth.visitor.create(visitor_name, zones[], valid_until)
      ▼
┌─────────────────────────────────────────────────────┐
│                   bAuth JSON-RPC                     │
│  1. Validar que anfitrión tiene permiso D2           │
│  2. Validar que zones[] ⊆ zonas autorizadas          │
│     del anfitrión (no puede delegar más de lo        │
│     que él mismo tiene)                              │
│  3. Validar valid_until <= now + 24h                 │
│  4. Crear registro en visitor_access_policy          │
│  5. Crear challenge en qr_challenge_registry         │
│  6. Generar QR firmado (válido solo para este        │
│     registro)                                        │
└──────────────┬──────────────────────────────────────┘
               │
               ▼
    visitor_access_policy
    ─────────────────────
    status = 'ACTIVE'
    valid_from = now()
    valid_until = (solicitado)
    allowed_zones = [...]
    qr_challenge_id = UUID
               │
        ┌──────┴──────────────────────────┐
        │                                 │
        ▼                                 ▼
  Visitante llega            Tiempo vence / anfitrión revoca
  escanea QR                        │
        │                            ▼
        ▼                    bauth.visitor.revoke(policy_id)
  bAuth valida:                      │
  - status = ACTIVE?                 ▼
  - now() < valid_until?    UPDATE status = 'REVOKED'
  - zone ∈ allowed_zones?   SET revoked_at = now()
        │
        ▼
  ACCESO CONCEDIDO
  (log en geo_location_log
   + aud_event)
```

**Diagrama de estados:**

```
                    bauth.visitor.create()
                           │
                           ▼
                      ┌─────────┐
                      │ ACTIVE  │
                      └────┬────┘
                           │
              ┌────────────┴────────────┐
              │                         │
     valid_until < now()      bauth.visitor.revoke()
    (job periódico)            (anfitrión o admin)
              │                         │
              ▼                         ▼
        ┌──────────┐             ┌──────────┐
        │ EXPIRED  │             │ REVOKED  │
        └──────────┘             └──────────┘
              │                         │
              └───────────┬─────────────┘
                          │
                   Estado terminal
                   (no reversible)
                   audit trail queda
```

---

### Grupo 3 — Registros operacionales (`emergency_override_policy`)

Break-glass: acceso de emergencia con doble autorización y ventana temporal acotada.

```
 USUARIO EN EMERGENCIA        SUPERUSUARIO AUTORIZADOR
         │                              │
         │  solicita override           │
         │  (ticket ITSM ref)           │
         ▼                              ▼
┌─────────────────────────────────────────────────────┐
│               bauth.emergency.open()                 │
│                                                      │
│  1. STEP-SOD-OVERRIDE activado (AAL3 + dual         │
│     aprobación — ver ath_step_up_rule)               │
│  2. Validar ticket_ref no vacío                      │
│  3. valid_until <= now() + 4h (máximo)               │
│  4. override_physical = false por defecto            │
│     (requiere justificación extra para true)         │
│  5. Insertar en emergency_override_policy            │
│  6. Crear QR en qr_challenge_registry               │
│  7. Registrar en aud_event (nivel CRITICAL)          │
└──────────────┬──────────────────────────────────────┘
               │
               ▼
   emergency_override_policy
   ──────────────────────────
   status       = 'ACTIVE'
   override_geo = true   (bypasa geo_fence)
   override_temporal = true (bypasa horarios)
   override_physical = false
   allowed_zones = [...] (acotado, no ilimitado)
   valid_until = now() + Xh
               │
        ┌──────┴──────────────────────────────┐
        │                                      │
        ▼                                      ▼
 Durante la ventana:              Al cerrar / al vencer:
 - Usuario tiene acceso           bauth.emergency.close()
   a allowed_zones sin                    │
   restricciones D4/D6                    ▼
 - CADA acción se audita          UPDATE status = 'REVOKED'
   en aud_event con               SET revoked_at = now()
   override_id como               + aud_event CRITICAL
   ctx_id adicional               + notificación al SIEM
```

**Diagrama de estados con aprobación dual:**

```
  Solicitud
      │
      ▼
 ┌──────────────┐
 │  PENDIENTE   │  (solo si se implementa flujo
 │  APROBACIÓN  │   de doble aprobación asíncrona)
 └──────┬───────┘
        │  aprobador confirma (AAL3)
        ▼
   ┌─────────┐◄──── solo se puede extender una vez
   │ ACTIVE  │      (max +2h adicionales)
   └────┬────┘
        │
   ┌────┴────────────────────┐
   │                         │
valid_until < now()   bauth.emergency.close()
        │              (manual — obligatorio
        ▼               al resolver incidente)
  ┌──────────┐               │
  │ EXPIRED  │               ▼
  └──────────┘         ┌──────────┐
        │              │ REVOKED  │
        └──────┬───────┘
               │
        Estado terminal
        Audit trail permanente
        (retención 7 años — AUDIT_RETENTION_7Y)
```

---

### Resumen visual de qué actor toca qué tabla

```
                         ACTORES
     ┌───────────────────────────────────────────────────┐
     │   Admin       Superusuario    Anfitrión    Job     │
     │  (BIZ_N1)        (SU)        (empleado)  (sistema)│
     └──┬────────────────┬──────────────┬───────────┬───┘
        │                │              │           │
        ▼                ▼              ▼           ▼
   zone_button_      net_ztna_      visitor_    zone_*
   rule             policy         access_     (PEP evalúa
   zone_record_     geo_velocity_  policy      en tiempo
   rule             policy         (CREATE/    real al
   zone_data_       ses_risk_      REVOKE)     emitir JWT)
   policy           policy
   (CREATE/         conflict_
   UPDATE)          interest_
                    policy
                    (UPDATE only)
                                   emergency_
                                   override_
                                   (OPEN requiere
                                   aprobación SU
                                   + AAL3 dual)
```

---

## 11. Estructura de datos y flujos CRUD por tabla

---

### `zone_button_rule`

**Qué almacena:** una regla por cada combinación zona + aplicación + modelo + botón.
Define si ese botón está habilitado, cuántas personas deben aprobar la acción,
si hay SoD que prohíbe al mismo usuario que hizo X también hacer Y, y si requiere
step-up de AAL.

**Campos:**

| Campo | Tipo | Obligatorio | Valores posibles |
|---|---|---|---|
| `rule_id` | uuid | auto (uuidv7) | — |
| `zone_id` | text | sí | FK → `log_zone.zona_id` |
| `app_code` | smallint | sí | FK → `privilege_application.app_code` |
| `model_name` | text | sí | Nombre del modelo de datos (ej: `account.invoice`) |
| `button_name` | text | sí | Nombre del botón/acción (ej: `void`, `post`, `approve`) |
| `condition_json` | jsonb | no | Condición adicional en JSONB (ej: `{"amount_gte": 5000}`) |
| `users_required` | integer | sí | `1` (uno) o `2` (dual — dos usuarios distintos) |
| `sod_cannot_also` | text | no | Nombre del botón que el mismo usuario no puede haber ejecutado (SoD) |
| `step_up_loa` | integer | no | `null`, `2` o `3` — nivel AAL requerido para ejecutar |
| `description` | text | no | Descripción legible de la regla |
| `is_active` | boolean | sí | `true` / `false` |

**Ejemplo de registro:**
```
zone_id       = "ZONA-FIN-LPZ"
app_code      = 3
model_name    = "account.invoice"
button_name   = "void"
condition_json= {"amount_gte": 1000}
users_required= 2
sod_cannot_also = "post"
step_up_loa   = 3
description   = "Anular factura > 1000 BOB: dual + AAL3. Quien emitió no puede anular."
is_active     = true
```

**CRUD:**

```
CREAR
  Actor   : Admin (BIZ_N1, AAL3)
  Método  : bauth.zone.button_rule.create(zone_id, app_code, model_name, button_name, ...)
  Valida  : zone_id ∈ log_zone · app_code ∈ privilege_application
            UNIQUE (zone_id, app_code, model_name, button_name) — no duplicar
  Resultado: INSERT → rule_id generado · aud_policy_change registrado

LEER
  Filtros : zone_id, app_code, model_name, is_active
  Uso     : bAuth PEP lo consulta en cada evaluación de acción de usuario

MODIFICAR
  Campos editables: condition_json, users_required, sod_cannot_also,
                    step_up_loa, description, is_active
  Campos no editables: zone_id, app_code, model_name, button_name (son la clave)
  Actor   : Admin (BIZ_N1, AAL3) + aud_policy_change

DESACTIVAR (no hay delete físico)
  UPDATE SET is_active = false
  La regla deja de evaluarse. Queda en historial de aud_policy_change.

DELETE FÍSICO
  Solo superusuario (SU) puede borrar.
  Condición: is_active = false previamente.
  Se registra en aud_event nivel CRITICAL.
```

---

### `zone_data_policy`

**Qué almacena:** una política por zona que define qué tipos de datos sensibles
puede ver esa zona y cómo se tratan (enmascaramiento, retención, base legal GDPR).

**Campos:**

| Campo | Tipo | Obligatorio | Valores posibles |
|---|---|---|---|
| `policy_id` | uuid | auto | — |
| `zone_id` | text | sí | FK → `log_zone.zona_id` · UNIQUE (una sola por zona) |
| `data_classification` | text[] | no | `{PUBLIC}`, `{INTERNAL}`, `{CONFIDENTIAL}`, `{RESTRICTED}` |
| `pii_access` | boolean | no | `true` / `false` (default false) |
| `phi_access` | boolean | no | `true` / `false` (datos de salud) |
| `gdpr_sensitive` | boolean | no | `true` / `false` (datos sensibles Art.9) |
| `masking_policy` | text | no | `FULL`, `PARTIAL`, `NONE` |
| `retention_days` | integer | no | días de retención de datos de esa zona |
| `gdpr_lawful_basis` | text | no | `consent`, `contract`, `legal_obligation`, `legitimate_interest` |
| `is_active` | boolean | sí | `true` / `false` |

**Ejemplo de registro:**
```
zone_id            = "ZONA-RRHH-CENTRAL"
data_classification= {CONFIDENTIAL, RESTRICTED}
pii_access         = true
phi_access         = false
gdpr_sensitive     = true
masking_policy     = "PARTIAL"     (ej: CI ***-**-1234)
retention_days     = 1825          (5 años — Ley 843 Bolivia)
gdpr_lawful_basis  = "contract"
is_active          = true
```

**CRUD:**

```
CREAR
  Actor   : Admin (BIZ_N1, AAL3)
  Método  : bauth.zone.data_policy.create(zone_id, classification, ...)
  Valida  : zone_id ∈ log_zone · solo UNA política por zone_id (UNIQUE)
  Resultado: INSERT · aud_policy_change

LEER
  Por zone_id (lookup directo — clave única)
  bAuth PEP consulta al evaluar acceso a campo sensible

MODIFICAR
  Todos los campos editables excepto zone_id
  Actor: Admin (BIZ_N1, AAL3) + aud_policy_change

DESACTIVAR / REEMPLAZAR
  No se borra — se desactiva (is_active = false) y se crea una nueva.
  Solo una activa por zone_id en cualquier momento.
```

---

### `zone_record_rule`

**Qué almacena:** el scope de registros que un usuario de una zona puede ver
en un modelo de datos específico. bAuth incluye este scope como claim en el JWT.

**Campos:**

| Campo | Tipo | Obligatorio | Valores posibles |
|---|---|---|---|
| `rule_id` | uuid | auto | — |
| `zone_id` | text | sí | FK → `log_zone.zona_id` |
| `app_code` | smallint | sí | FK → `privilege_application.app_code` |
| `model_name` | text | sí | Modelo de datos afectado |
| `domain_json` | text | sí | Expresión de dominio (ej: `branch_id = $user.branch`) |
| `scope` | text | sí | `BRANCH` / `REGIONAL` / `GLOBAL` |
| `perm_write_exception` | boolean | no | `true` si puede escribir fuera de scope en casos de excepción |
| `description` | text | no | — |
| `is_active` | boolean | sí | `true` / `false` |

**Ejemplo de registro:**
```
zone_id       = "ZONA-VTAS-SUCURSAL"
app_code      = 2
model_name    = "sale.order"
domain_json   = "company_id = $user.company_id AND branch_id = $user.branch_id"
scope         = "BRANCH"
perm_write_exception = false
description   = "Vendedor de sucursal solo ve órdenes de su sucursal"
is_active     = true
```

**CRUD:**

```
CREAR
  Actor   : Admin (BIZ_N1, AAL3)
  Método  : bauth.zone.record_rule.create(zone_id, app_code, model_name, domain_json, scope)
  Valida  : zone_id ∈ log_zone · app_code ∈ privilege_application
            Sintaxis de domain_json válida (no inyección SQL)
  Resultado: INSERT · aud_policy_change

LEER
  Filtros: zone_id, app_code, model_name, scope
  bAuth emite el claim `record_scope` en el JWT con el valor resultante

MODIFICAR
  Editables: domain_json, scope, perm_write_exception, description, is_active
  No editables: zone_id, app_code, model_name (clave de negocio)

DESACTIVAR
  is_active = false → el JWT deja de incluir restricción de scope
  (equivale a scope GLOBAL — máximo permiso, usar con cautela)
```

---

### `net_ztna_policy`

**Qué almacena:** singleton global de la política ZTNA del sistema.
**Siempre hay exactamente una fila activa.**

**Campos:**

| Campo | Tipo | Obligatorio | Valores posibles |
|---|---|---|---|
| `policy_id` | uuid | auto | — |
| `default_action` | text | sí | `DENY` (recomendado) / `ALLOW` |
| `allowed_services` | text[] | no | Lista de servicios permitidos por defecto (`{bauth,biedata,...}`) |
| `microsegmentation` | boolean | sí | `true` / `false` |
| `require_just_in_time` | boolean | no | `true` = acceso JIT obligatorio (STEP-DELEGATION) |
| `verification_interval_s` | integer | no | Segundos entre re-verificaciones (default 300 = 5 min) |
| `is_active` | boolean | sí | `true` / `false` |

**Ejemplo de registro (seed canónico):**
```
default_action         = "DENY"
allowed_services       = {bauth, biedata, bsearch}
microsegmentation      = true
require_just_in_time   = false
verification_interval_s= 300
is_active              = true
```

**CRUD:**

```
CREAR (solo al instalar el sistema — seed)
  No hay método JSON-RPC de creación.
  Se inserta vía bauth_77__singleton_policies.sql (seed pendiente).

LEER
  bAuth PrivilegeEngine D7 lo carga al iniciar y recarga cada 60 s.
  No hay API pública de lectura directa (uso interno del motor).

MODIFICAR
  Actor   : Superusuario (SU, AAL3, STEP-SYSTEM-CONFIG activado)
  Método  : bauth.config.ztna.update(default_action, verification_interval_s, ...)
  Valida  : CHECK default_action IN ('DENY','ALLOW')
  Efecto  : UPDATE WHERE is_active = true
            Motor recarga en < 1 s vía notificación interna

NO HAY DELETE
  Solo is_active = false (deja el sistema sin política ZTNA — peligroso)
  Si se desactiva, el motor usa DENY como fallback hardcodeado.
```

---

### `geo_velocity_policy`

**Qué almacena:** singleton global de umbrales del detector de impossible travel.
**Siempre hay exactamente una fila activa.**

**Campos:**

| Campo | Tipo | Obligatorio | Valores posibles |
|---|---|---|---|
| `policy_id` | uuid | auto | — |
| `max_velocity_kmh` | integer | sí | velocidad máxima antes de alertar (default 900) |
| `tolerance_km` | integer | sí | tolerancia en km (default 10) |
| `window_minutes` | integer | sí | ventana de tiempo para comparar posiciones (default 5) |
| `on_violation` | text | sí | `REQUIRE_STEP_UP` / `TERMINATE_SESSION` / `LOCK_ACCOUNT` / `LOG_ONLY` |
| `max_violations` | integer | no | violaciones antes de acción más severa (default 3) |
| `violation_cooldown_minutes` | integer | no | minutos de cooldown tras violación (default 30) |
| `is_active` | boolean | sí | `true` / `false` |

**Ejemplo de registro (seed canónico):**
```
max_velocity_kmh          = 900
tolerance_km              = 10
window_minutes            = 5
on_violation              = "REQUIRE_STEP_UP"
max_violations            = 3
violation_cooldown_minutes= 30
is_active                 = true
```

**CRUD:**

```
CREAR  : solo seed inicial
LEER   : GeoEngine D6 lo carga en memoria al iniciar
MODIFICAR
  Actor  : Superusuario (SU, AAL3)
  Método : bauth.config.geo_velocity.update(max_velocity_kmh, on_violation, ...)
  Valida : CHECK on_violation IN ('REQUIRE_STEP_UP','TERMINATE_SESSION',
                                   'LOCK_ACCOUNT','LOG_ONLY')
           max_velocity_kmh BETWEEN 100 AND 2000
NO HAY DELETE : fallback hardcodeado 900 km/h si se desactiva
```

---

### `ses_risk_policy`

**Qué almacena:** singleton global de umbrales del motor de riesgo de sesión.
**Siempre hay exactamente una fila activa.**

**Campos:**

| Campo | Tipo | Obligatorio | Valores posibles |
|---|---|---|---|
| `policy_id` | uuid | auto | — |
| `risk_factors` | text[] | sí | Fuentes de riesgo activas: `{geo_velocity, device_trust, impossible_travel, ...}` |
| `threshold_low` | integer | no | score < este valor = riesgo bajo (default 30) |
| `threshold_medium` | integer | no | score < este valor = riesgo medio (default 60) |
| `threshold_high` | integer | no | score < este valor = riesgo alto (default 80) |
| `threshold_critical` | integer | no | score < este valor = riesgo crítico (default 95) |
| `action_low` | text | no | `NONE` / `LOG` / `REQUIRE_STEP_UP` |
| `action_medium` | text | no | `NONE` / `LOG` / `REQUIRE_STEP_UP` / `TERMINATE_SESSION` |
| `action_high` | text | no | `REQUIRE_STEP_UP` / `TERMINATE_SESSION` |
| `action_critical` | text | no | `TERMINATE_SESSION` / `LOCK_ACCOUNT` |
| `is_active` | boolean | sí | `true` / `false` |

**Ejemplo de registro (seed canónico):**
```
risk_factors    = {geo_velocity, device_trust, impossible_travel, new_device}
threshold_low   = 30,  action_low      = "NONE"
threshold_medium= 60,  action_medium   = "REQUIRE_STEP_UP"
threshold_high  = 80,  action_high     = "REQUIRE_STEP_UP"
threshold_critical=95, action_critical = "TERMINATE_SESSION"
is_active       = true
```

**CRUD:**

```
CREAR  : solo seed inicial
LEER   : SessionRiskEngine D8 lo carga al iniciar
MODIFICAR
  Actor  : Superusuario (SU, AAL3)
  Método : bauth.config.session_risk.update(thresholds, actions, risk_factors)
  Valida : CHECK constraints de acción (ver DDL)
           threshold_low < threshold_medium < threshold_high < threshold_critical
NO HAY DELETE : el motor necesita siempre una política activa
```

---

### `conflict_interest_policy`

**Qué almacena:** singleton global de la política de conflicto de interés.
**Siempre hay exactamente una fila activa.**

**Campos:**

| Campo | Tipo | Obligatorio | Valores posibles |
|---|---|---|---|
| `policy_id` | uuid | auto | — |
| `restricted_entity_types` | text[] | no | Tipos de entidad restringidos: `{supplier, client, competitor, family}` |
| `max_relationship_degrees` | integer | no | grados de separación que se consideran conflicto (default 2) |
| `declaration_frequency` | text | sí | `ANNUAL` / `QUARTERLY` / `ON_CHANGE` |
| `requires_update_on_change` | boolean | sí | Si debe declarar al cambiar relación (default true) |
| `verification_method` | text | sí | `COMPLIANCE_REVIEW` / `AUTOMATED_CHECK` / `MANAGER_APPROVAL` |
| `is_active` | boolean | sí | `true` / `false` |

**Ejemplo de registro (seed canónico):**
```
restricted_entity_types  = {supplier, client, competitor}
max_relationship_degrees = 2
declaration_frequency    = "ANNUAL"
requires_update_on_change= true
verification_method      = "COMPLIANCE_REVIEW"
is_active                = true
```

**CRUD:**

```
CREAR  : solo seed inicial
LEER   : ComplianceEngine D10/D3 lo consulta en validación de SoD
MODIFICAR
  Actor  : Superusuario (SU, AAL3) o Compliance Officer (rol específico)
  Método : bauth.config.conflict_interest.update(...)
NO HAY DELETE
```

---

### `visitor_access_policy`

**Qué almacena:** un registro por cada visita autorizada (operacional, no configuración).
Tiene ciclo de vida completo: ACTIVE → EXPIRED / REVOKED.

**Campos:**

| Campo | Tipo | Obligatorio | Valores posibles |
|---|---|---|---|
| `policy_id` | uuid | auto | — |
| `host_user_uuid` | uuid | sí | UUID del empleado anfitrión (FK → idn_user_template) |
| `visitor_user_uuid` | uuid | no | UUID si el visitante ya tiene cuenta en el sistema |
| `visitor_name` | text | no | Nombre del visitante externo |
| `visitor_phone` | text | no | Teléfono de contacto |
| `allowed_zones` | text[] | sí | Zonas a las que puede acceder |
| `restricted_zones` | text[] | no | Zonas explícitamente prohibidas |
| `allowed_services` | text[] | no | Servicios digitales accesibles durante la visita |
| `valid_from` | timestamptz | sí | Inicio de la ventana de acceso |
| `valid_until` | timestamptz | sí | Fin de la ventana (CHECK valid_until > valid_from) |
| `can_control_devices` | boolean | no | Si puede operar dispositivos físicos (default false) |
| `max_visitors` | integer | no | Visitantes cubiertos por esta autorización (default 1) |
| `status` | text | auto | `ACTIVE` / `EXPIRED` / `REVOKED` |
| `qr_challenge_id` | uuid | auto | FK → `qr_challenge_registry` (generado al crear) |
| `revoked_at` | timestamptz | no | Timestamp de revocación manual |

**Ejemplo de registro:**
```
host_user_uuid  = <UUID del empleado que invita>
visitor_name    = "Carlos Mamani"
visitor_phone   = "+591 70123456"
allowed_zones   = {"ZONA-RECEPCION", "ZONA-SALA-REUNIONES-A"}
restricted_zones= {"ZONA-SERVIDORES", "ZONA-CONTABILIDAD"}
valid_from      = 2026-07-08 09:00:00-04
valid_until     = 2026-07-08 17:00:00-04
can_control_devices = false
status          = "ACTIVE"
qr_challenge_id = <UUID generado>
```

**CRUD:**

```
CREAR (bauth.visitor.create)
  Actor   : Empleado con permiso D2.visitor.host (cualquier tier BIZ)
  Campos  : visitor_name/phone o visitor_user_uuid, allowed_zones,
            valid_from, valid_until, max_visitors
  Valida  : allowed_zones ⊆ zonas del anfitrión (no puede delegar más de lo propio)
            valid_until - valid_from ≤ 24h (política D4)
            Anfitrión no puede crear visita cuando él mismo está de vacaciones
  Efecto  : INSERT → genera qr_challenge_id → devuelve QR firmado para imprimir

LEER (bauth.visitor.list)
  Filtros : status='ACTIVE', host_user_uuid, zone_id, fecha
  Uso     : Panel de recepción para ver visitas activas del día

LEER (bauth.visitor.validate_qr)
  Input   : qr_challenge_id escaneado en recepción
  Valida  : status='ACTIVE' AND valid_from<=now()<=valid_until
            zone escaneada ∈ allowed_zones
  Efecto  : Registra en geo_location_log + aud_event

MODIFICAR (bauth.visitor.extend)
  Solo: valid_until (extender hasta max 2h adicionales)
  Actor: Anfitrión o Admin
  No se pueden cambiar: allowed_zones (para cambiar zonas → revocar y crear nueva)

REVOCAR (bauth.visitor.revoke)
  Actor   : Anfitrión, Admin, o Seguridad (BIZ_N1)
  Efecto  : UPDATE status='REVOKED', revoked_at=now()
            QR invalidado en qr_challenge_registry
            aud_event registrado

EXPIRAR (job automático)
  Cron cada 5 min: UPDATE status='EXPIRED' WHERE valid_until < now() AND status='ACTIVE'
  No hay acción manual — ocurre automáticamente

NO HAY DELETE FÍSICO
  Los registros se conservan por auditoría (retención según zona)
```

---

### `emergency_override_policy`

**Qué almacena:** un registro por cada break-glass activo. Permite a un usuario
operar fuera de sus restricciones normales (geo, temporal) durante una emergencia,
con doble autorización y trazabilidad completa.

**Campos:**

| Campo | Tipo | Obligatorio | Valores posibles |
|---|---|---|---|
| `override_id` | uuid | auto | — |
| `authorized_by` | uuid | sí | UUID del superusuario que autoriza (SU, AAL3) |
| `authorized_for` | uuid | sí | UUID del usuario que recibe el override |
| `reason` | text | sí | Justificación textual obligatoria |
| `ticket_ref` | text | no | Referencia al ticket ITSM/incidente |
| `override_geo` | boolean | no | Bypasa restricciones geográficas (default true) |
| `override_temporal` | boolean | no | Bypasa restricciones de horario (default true) |
| `override_physical` | boolean | no | Bypasa restricciones físicas (default **false** — alto riesgo) |
| `allowed_zones` | text[] | no | Zonas a las que puede acceder durante el override |
| `valid_from` | timestamptz | sí | Inicio (default now()) |
| `valid_until` | timestamptz | sí | Fin máximo 4h desde valid_from |
| `status` | text | auto | `ACTIVE` / `EXPIRED` / `REVOKED` |
| `qr_challenge_id` | uuid | no | FK → `qr_challenge_registry` |
| `revoked_at` | timestamptz | no | Timestamp de cierre manual |

**Ejemplo de registro:**
```
authorized_by    = <UUID superusuario>
authorized_for   = <UUID técnico en emergencia>
reason           = "Falla eléctrica en Sucursal Cochabamba — acceso fuera de horario para restablecer servidores"
ticket_ref       = "INC-2026-07-08-0042"
override_geo     = true    (puede entrar desde cualquier ubicación)
override_temporal= true    (puede operar fuera de horario)
override_physical= false   (NO puede abrir puertas de zonas físicas restringidas)
allowed_zones    = {"ZONA-SERVIDORES-CBB"}
valid_from       = 2026-07-08 02:00:00-04
valid_until      = 2026-07-08 05:00:00-04   (3h máximo)
status           = "ACTIVE"
```

**CRUD:**

```
ABRIR (bauth.emergency.open)
  Actor   : Superusuario (SU) — requiere STEP-SOD-OVERRIDE (AAL3 + aprobación dual)
  Campos  : authorized_for, reason, ticket_ref, override_*, allowed_zones, valid_until
  Valida  : valid_until - now() ≤ 4h (máximo absoluto)
            override_physical = true → requiere justificación adicional y segundo SU
            authorized_for ≠ authorized_by (no puede auto-autorizarse)
  Efecto  : INSERT → aud_event CRITICAL → notificación SIEM Wazuh
            Cada acción del usuario durante el override incluye override_id en ctx_id

LEER (bauth.emergency.list_active)
  Solo para SU y Admin
  Muestra: quién, para quién, desde cuándo, hasta cuándo, qué bypasó

EXTENDER (bauth.emergency.extend)
  Actor : Superusuario (SU, AAL3)
  Máximo: +2h una sola vez (valid_until <= apertura + 6h absoluto)
  Efecto: UPDATE valid_until + aud_event

CERRAR (bauth.emergency.close) — OBLIGATORIO al resolver incidente
  Actor : Superusuario (SU) o el mismo usuario beneficiario
  Efecto: UPDATE status='REVOKED', revoked_at=now()
          aud_event CRITICAL "override cerrado"
          Notificación SIEM de cierre

EXPIRAR (job automático)
  UPDATE status='EXPIRED' WHERE valid_until < now() AND status='ACTIVE'

AUDITAR (bauth.emergency.audit)
  Devuelve: todos los eventos aud_event donde ctx_id contiene override_id
  Genera reporte de qué hizo el usuario durante el override
  Retención: 7 años (AUDIT_RETENTION_7Y)

NO HAY DELETE FÍSICO NUNCA
  Es evidencia de auditoría — solo SU puede ver el historial completo
```

---

### Tabla comparativa: tipo de operación por tabla

```
Tabla                    CREAR      LEER    MODIFICAR  DESACTIVAR  DELETE
─────────────────────────────────────────────────────────────────────────
zone_button_rule         Admin      PEP     Admin      Admin       SU only
zone_data_policy         Admin      PEP     Admin      Admin       SU only
zone_record_rule         Admin      PEP     Admin      Admin       SU only
net_ztna_policy          seed only  Motor   SU+AAL3    peligroso   nunca
geo_velocity_policy      seed only  Motor   SU+AAL3    peligroso   nunca
ses_risk_policy          seed only  Motor   SU+AAL3    peligroso   nunca
conflict_interest_policy seed only  Motor   SU+AAL3    —           nunca
visitor_access_policy    Empleado   Admin   Anfitrión  automático  nunca
emergency_override_policy SU+dual   SU      SU+AAL3    automático  nunca
```
