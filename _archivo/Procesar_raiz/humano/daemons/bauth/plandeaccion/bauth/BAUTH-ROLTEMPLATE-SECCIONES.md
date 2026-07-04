# BAUTH-ROLTEMPLATE-SECCIONES.md — Contrato Definitivo v6.0

**Versión:** 6.0 · **Fecha:** 2026-06-24 · **Autor:** sbos-coordinador
**Fuentes:** `SBOS-ROLTEMPLATE-v5_0.md` · `SBOS-USERTEMPLATE-v5_0.md` · `BAUTH-COMPLETITUD-DOMINIOS-STANDARDS.md`
**Evaluado contra:** Okta Fine-Grained Auth (Zanzibar) · Auth0 FGA (Relation-Based) · Keycloak 26.x (9 Policy Types)
  · Entra ID Custom Roles · SailPoint IIQ · OPA/Rego (Policy-as-Code) · CyberArk PAM
**Estándares:** NIST SP 800-63B-4 Final (Jul 2025) · OpenID CAEP/SSF Final (Sept 2025) · ISO 27001:2022
  · PCI DSS 4.0.1 · RFC 9470 Step-Up · FIDO2/WebAuthn Level 3 · OWASP ASVS V2 (2024) · SBOS-049

---

# SECCIÓN 1 — `logical_access` (D1 — LÓGICO)

**Dominio:** D1 — Lógico · **Tipo:** Fast-Path (<0.5ns) · **Orden evaluación:** 3° (D8→D9→D1→...)

**Propósito integral:** Controla TODO lo que el rol puede hacer en el mundo digital: qué aplicaciones usa,
con qué verbos, sobre qué datos, en qué zonas de negocio, bajo qué reglas de scope, con qué restricciones
de campo, bajo qué condiciones de step-up, qué menús ve, qué reportes ejecuta, qué excepciones temporales
tiene, y cómo se vincula con los demás dominios para enforcement.

---

## 1.1 — `availableMethods` — Catálogo Completo de Métodos Digitales

**Propósito:** Lista exhaustiva de TODOS los métodos de autenticación digital que el sistema soporta
y que este rol PODRÍA usar. No todos son obligatorios — ver `requiredMethods`.

**Estándar:** NIST SP 800-63B-4 §4-5 · FIDO2 WebAuthn Level 3 · OAuth 2.1

**Catálogo:** `ath_method` (26 métodos + 15 biométricos)

```json
{
  "logical_access": {
    "availableMethods": [
      {
        "methodId": "PASSWORD",
        "methodName": "Password / Memorized Secret",
        "methodType": "MEMORIZED_SECRET",
        "loaMin": 1,
        "loaMax": 2,
        "tool": "keycloak",
        "standard": "NIST SP 800-63B-4 §4.1",
        "is_phishing_resistant": false,
        "is_device_bound": false,
        "can_be_primary": true,
        "can_be_fallback": false,
        "recovery_eligible": false,
        "min_length": 12,
        "max_age_days": null,
        "description": "Password tradicional. NIST Rev.4: NO rotación periódica, NO reglas de complejidad, SI verificación HIBP."
      },
      {
        "methodId": "TOTP",
        "methodName": "Time-Based One-Time Password",
        "methodType": "OTP_APP",
        "loaMin": 2,
        "loaMax": 2,
        "tool": "keycloak",
        "standard": "RFC 6238",
        "is_phishing_resistant": false,
        "is_device_bound": false,
        "can_be_primary": false,
        "can_be_fallback": true,
        "recovery_eligible": false,
        "step_seconds": 30,
        "digits": 6,
        "algorithm": "SHA256",
        "description": "OTP basado en tiempo vía app autenticadora (Aegis, Google Auth, Authy)."
      },
      {
        "methodId": "HOTP",
        "methodName": "HMAC-Based One-Time Password",
        "methodType": "OTP_HW",
        "loaMin": 2,
        "loaMax": 2,
        "tool": "keycloak",
        "standard": "RFC 4226",
        "is_phishing_resistant": false,
        "is_device_bound": true,
        "can_be_primary": false,
        "can_be_fallback": true,
        "recovery_eligible": false,
        "digits": 6,
        "look_ahead_window": 5,
        "description": "OTP basado en contador para tokens hardware (YubiKey OTP, Nitrokey)."
      },
      {
        "methodId": "WEBAUTHN_PWDLESS",
        "methodName": "WebAuthn Passkey (Discoverable)",
        "methodType": "FIDO2",
        "loaMin": 2,
        "loaMax": 3,
        "tool": "keycloak",
        "standard": "FIDO2 Level 2 / WebAuthn W3C",
        "is_phishing_resistant": true,
        "is_device_bound": false,
        "can_be_primary": true,
        "can_be_fallback": true,
        "recovery_eligible": false,
        "attestation": "indirect",
        "user_verification": "required",
        "resident_key": "required",
        "syncable": true,
        "max_aal": "AAL2",
        "description": "Passkey sincronizable (iCloud Keychain, Google Password Manager). Phishing-resistant. NIST Rev.4: PERMITIDO en AAL2, PROHIBIDO en AAL3."
      },
      {
        "methodId": "WEBAUTHN_2FA",
        "methodName": "WebAuthn Second Factor (Non-Discoverable)",
        "methodType": "FIDO2",
        "loaMin": 2,
        "loaMax": 2,
        "tool": "keycloak",
        "standard": "FIDO2 Level 1 / WebAuthn W3C",
        "is_phishing_resistant": true,
        "is_device_bound": true,
        "can_be_primary": false,
        "can_be_fallback": true,
        "recovery_eligible": false,
        "attestation": "none",
        "user_verification": "discouraged",
        "resident_key": "discouraged",
        "syncable": false,
        "max_aal": "AAL2",
        "description": "Llave de seguridad externa como segundo factor (YubiKey, SoloKey, Feitian). Token no residente."
      },
      {
        "methodId": "PASSKEY_DEVICE",
        "methodName": "Passkey Device-Bound (Hardware)",
        "methodType": "FIDO2_HW",
        "loaMin": 3,
        "loaMax": 4,
        "tool": "keycloak",
        "standard": "FIDO2 Level 3 / FIPS 140-3",
        "is_phishing_resistant": true,
        "is_device_bound": true,
        "can_be_primary": true,
        "can_be_fallback": false,
        "recovery_eligible": false,
        "attestation": "direct",
        "user_verification": "required",
        "resident_key": "required",
        "syncable": false,
        "max_aal": "AAL3",
        "requires_fips": true,
        "description": "Passkey device-bound con FIPS 140-3. Clave privada no exportable. Obligatorio para AAL3 según NIST Rev.4."
      },
      {
        "methodId": "SMARTCARD_X509",
        "methodName": "Smart Card X.509 PIV",
        "methodType": "PKI",
        "loaMin": 3,
        "loaMax": 4,
        "tool": "keycloak",
        "standard": "FIPS 201-3 PIV / NIST SP 800-73-5",
        "is_phishing_resistant": true,
        "is_device_bound": true,
        "can_be_primary": true,
        "can_be_fallback": false,
        "recovery_eligible": false,
        "certificate_format": "X.509v3",
        "key_algorithm": "RSA-2048 / ECDSA-P256",
        "requires_pin": true,
        "pin_min_length": 6,
        "pin_max_attempts": 3,
        "description": "Tarjeta inteligente PIV/CAC con certificado X.509. LoA 3-4. Uso federal/gobierno."
      },
      {
        "methodId": "MAGIC_LINK",
        "methodName": "Magic Link (Email)",
        "methodType": "MAGIC_LINK",
        "loaMin": 1,
        "loaMax": 1,
        "tool": "keycloak",
        "standard": null,
        "is_phishing_resistant": false,
        "is_device_bound": false,
        "can_be_primary": true,
        "can_be_fallback": true,
        "recovery_eligible": false,
        "ttl_seconds": 300,
        "single_use": true,
        "description": "Enlace mágico enviado por email. Un solo uso, TTL 5 minutos. LoA 1 únicamente."
      },
      {
        "methodId": "EMAIL_OTP",
        "methodName": "OTP por Email",
        "methodType": "OTP_EMAIL",
        "loaMin": 1,
        "loaMax": 1,
        "tool": "keycloak",
        "standard": null,
        "is_phishing_resistant": false,
        "is_device_bound": false,
        "can_be_primary": false,
        "can_be_fallback": true,
        "recovery_eligible": true,
        "digits": 6,
        "ttl_seconds": 600,
        "description": "OTP enviado a email. Solo LoA 1 o recuperación. NIST Rev.4: email NO recomendado para MFA AAL2."
      },
      {
        "methodId": "SMS_OTP",
        "methodName": "OTP por SMS",
        "methodType": "OTP_SMS",
        "loaMin": 1,
        "loaMax": 1,
        "tool": "keycloak",
        "standard": null,
        "is_phishing_resistant": false,
        "is_device_bound": false,
        "can_be_primary": false,
        "can_be_fallback": false,
        "recovery_eligible": false,
        "digits": 6,
        "ttl_seconds": 300,
        "deprecated": true,
        "deprecation_target": "2027-01-01",
        "description": "⚠️ DEPRECADO por NIST SP 800-63B-4 Final (Jul 2025). Vulnerable a SIM-swap y SS7. Solo mantenido para roles legacy. Migrar a TOTP o Passkey."
      },
      {
        "methodId": "BACKUP_CODES",
        "methodName": "Códigos de Respaldo",
        "methodType": "RECOVERY",
        "loaMin": 1,
        "loaMax": 1,
        "tool": "keycloak",
        "standard": null,
        "is_phishing_resistant": false,
        "is_device_bound": false,
        "can_be_primary": false,
        "can_be_fallback": true,
        "recovery_eligible": false,
        "code_count": 10,
        "code_digits": 8,
        "single_use": true,
        "requires_other_mfa": true,
        "description": "Códigos de respaldo de un solo uso. Solo disponibles si el usuario tiene MFA configurado."
      },
      {
        "methodId": "OAUTH_M2M",
        "methodName": "OAuth 2.1 Client Credentials (M2M)",
        "methodType": "OAUTH_M2M",
        "loaMin": 0,
        "loaMax": 0,
        "tool": "keycloak",
        "standard": "OAuth 2.1 / RFC 6749 + RFC 7636",
        "is_phishing_resistant": true,
        "is_device_bound": true,
        "can_be_primary": true,
        "can_be_fallback": false,
        "recovery_eligible": false,
        "requires_pkce": true,
        "requires_dpop": false,
        "description": "Client credentials para service accounts (M2M). PKCE obligatorio (OAuth 2.1). Sin usuario humano."
      },
      {
        "methodId": "CONDITIONAL_OTP",
        "methodName": "OTP Condicional (Step-Up)",
        "methodType": "STEP_UP",
        "loaMin": 2,
        "loaMax": 3,
        "tool": "keycloak",
        "standard": "RFC 9470",
        "is_phishing_resistant": false,
        "is_device_bound": false,
        "can_be_primary": false,
        "can_be_fallback": true,
        "recovery_eligible": false,
        "description": "Segundo factor condicional disparado por reglas de step-up (RFC 9470). Solo se activa cuando una operación requiere LoA mayor."
      },
      {
        "methodId": "CIBA_DECOUPLED",
        "methodName": "CIBA Decoupled Auth",
        "methodType": "CIBA",
        "loaMin": 2,
        "loaMax": 3,
        "tool": "keycloak",
        "standard": "OpenID CIBA / FAPI 2.0",
        "is_phishing_resistant": false,
        "is_device_bound": true,
        "can_be_primary": false,
        "can_be_fallback": true,
        "recovery_eligible": false,
        "binding_message": true,
        "description": "Autenticación desacoplada vía app móvil. El usuario aprueba en su teléfono sin compartir credenciales con la app cliente."
      }
    ],
```

---

## 1.2 — `requiredMethods` — Combinaciones de Factores por Contexto

**Propósito:** Define QUÉ combinación de factores se necesita para CADA contexto de acceso. Cada entry
es un Authentication Flow distinto en Keycloak. No es un solo método — es una ORQUESTACIÓN de
múltiples factores con orden, obligatoriedad y alternativas.

**Estándar:** NIST SP 800-63B-4 AAL1/AAL2/AAL3 · RFC 9470 · FIDO2 Multi-Factor Ceremony

```json
    "requiredMethods": {
      "unauthenticated": [
        {
          "methodId": "MAGIC_LINK",
          "order": 1,
          "required": true,
          "description": "Acceso sin credenciales previas — solo enlace mágico"
        }
      ],
      "standard_login": [
        {
          "methodId": "PASSWORD",
          "order": 1,
          "required": true,
          "description": "Primer factor — lo que el usuario SABE"
        },
        {
          "methodId": "TOTP",
          "order": 2,
          "required": true,
          "description": "Segundo factor — lo que el usuario TIENE (app TOTP)"
        }
      ],
      "elevated_login": [
        {
          "methodId": "PASSWORD",
          "order": 1,
          "required": true,
          "description": "Primer factor — lo que el usuario SABE"
        },
        {
          "methodId": "WEBAUTHN_PWDLESS",
          "order": 2,
          "required": true,
          "description": "Segundo factor phishing-resistant — lo que el usuario ES/posee (Passkey biométrica)"
        }
      ],
      "hardware_protected_login": [
        {
          "methodId": "PASSKEY_DEVICE",
          "order": 1,
          "required": true,
          "description": "Passkey device-bound FIPS 140-3 — AAL3. Proxy de 'lo que el usuario TIENE + ES' en un solo gesto"
        },
        {
          "methodId": "TOTP",
          "order": 2,
          "required": true,
          "description": "Factor adicional fresco — garantiza presencia reciente del usuario"
        }
      ],
      "financial_high_value": [
        {
          "methodId": "WEBAUTHN_PWDLESS",
          "order": 1,
          "required": true,
          "description": "Passkey phishing-resistant como segundo factor"
        },
        {
          "methodId": "TOTP",
          "order": 2,
          "required": true,
          "description": "TOTP fresco como tercer factor para transacciones > límite_step_up"
        }
      ],
      "system_config_change": [
        {
          "methodId": "PASSKEY_DEVICE",
          "order": 1,
          "required": true,
          "description": "Solo Passkey device-bound para cambios de configuración del sistema"
        }
      ],
      "m2m_service_account": [
        {
          "methodId": "OAUTH_M2M",
          "order": 1,
          "required": true,
          "description": "Client credentials + PKCE para comunicación entre daemons"
        }
      ],
      "decoupled_external": [
        {
          "methodId": "CIBA_DECOUPLED",
          "order": 1,
          "required": true,
          "description": "Autenticación desacoplada para usuarios externos — aprobación en app móvil"
        }
      ]
    },
```

---

## 1.3 — `alternativeMethods` — Resiliencia ante Fallo

**Propósito:** Define qué hacer cuando un método requerido NO está disponible (dispositivo perdido,
sin soporte biométrico, sin cobertura celular). Cada alternativa define el sustituto, si requiere
aprobación de supervisor, y el límite de usos.

**Estándar:** NIST SP 800-63B-4 §5.2.3 (obligatorio ofrecer alternativa no biométrica)

```json
    "alternativeMethods": [
      {
        "replaces": "TOTP",
        "with": "BACKUP_CODES",
        "requiresApproval": true,
        "maxUses": 1,
        "maxUsesWindow": "24h",
        "reason": "Pérdida de dispositivo TOTP — requiere aprobación del supervisor",
        "notificationChannels": ["email", "rocket_chat"],
        "audit": "comprehensive"
      },
      {
        "replaces": "WEBAUTHN_PWDLESS",
        "with": "WEBAUTHN_2FA",
        "requiresApproval": false,
        "maxUses": null,
        "reason": "Dispositivo sin soporte Passkey nativo — usar llave de seguridad externa",
        "description": "Alternativa automática sin aprobación. El usuario conecta su YubiKey/Nitrokey."
      },
      {
        "replaces": "WEBAUTHN_PWDLESS",
        "with": "SMARTCARD_X509",
        "requiresApproval": true,
        "maxUses": null,
        "reason": "Requerimiento de seguridad elevado — usar tarjeta inteligente PIV en lugar de Passkey",
        "description": "Para roles que manejan datos RESTRICTED. Supervisor de seguridad debe aprobar."
      },
      {
        "replaces": "PASSWORD",
        "with": "MAGIC_LINK",
        "requiresApproval": false,
        "maxUses": 5,
        "maxUsesWindow": "24h",
        "reason": "Usuario olvidó su password — magic link como rescate temporal",
        "description": "5 usos en 24h. Después, requiere reset de password con aprobación de RRHH."
      },
      {
        "replaces": "CIBA_DECOUPLED",
        "with": "TOTP",
        "requiresApproval": true,
        "maxUses": null,
        "reason": "Usuario sin smartphone corporativo — usar TOTP en dispositivo personal",
        "description": "Requiere aprobación de seguridad. El dispositivo personal debe pasar verificación de postura."
      },
      {
        "replaces": "SMS_OTP",
        "with": "TOTP",
        "requiresApproval": false,
        "maxUses": null,
        "reason": "Migración forzosa desde SMS (deprecado) a TOTP",
        "description": "Automático. El sistema migra al usuario en su próximo login. SMS_OTP ELIMINADO post-2027."
      }
    ],
```

---

## 1.4 — `levelOfAssurance` y `stepUpRules`

**Propósito:** Define el LoA base del rol y las reglas CONDICIONALES que elevan temporalmente
ese nivel cuando una operación sensible lo requiere. Implementa RFC 9470 con `acr_values` y `max_age`.

**Estándar:** NIST SP 800-63B-4 AAL1/AAL2/AAL3 · RFC 9470 OAuth 2.0 Step-Up · OpenID Connect acr claim

```json
    "levelOfAssurance": 2,

    "stepUpRules": [
      {
        "ruleId": "STEP-FIN-APPROVE",
        "trigger": "financial_approve",
        "condition": {
          "type": "PYSON",
          "expression": "Eval('amount', 0) > Eval('user.financial_limits.transaction_limits.single_transaction_limit', 0)",
          "description": "Cuando el monto de la transacción excede el límite individual del rol"
        },
        "requiredLoa": 3,
        "maxAgeSeconds": 300,
        "acrValue": "sbos_aal3",
        "reauthRequired": true,
        "description": "Toda aprobación financiera por encima del límite requiere AAL3 (Passkey device-bound) fresco (últimos 5 min)."
      },
      {
        "ruleId": "STEP-SYSTEM-CONFIG",
        "trigger": "system_config_change",
        "condition": null,
        "requiredLoa": 3,
        "maxAgeSeconds": 0,
        "acrValue": "sbos_aal3_fresh",
        "reauthRequired": true,
        "description": "Cualquier cambio de configuración del sistema requiere AAL3 con autenticación CERO segundos de antigüedad. Reautenticación obligatoria."
      },
      {
        "ruleId": "STEP-USER-MGMT",
        "trigger": "user_role_assignment",
        "condition": {
          "type": "ROLE_CHECK",
          "targetRoles": ["ROL-SYS-ADMIN-*", "ROL-ORG-CFO", "ROL-ORG-CEO"],
          "description": "Asignar o modificar roles privilegiados dispara step-up"
        },
        "requiredLoa": 3,
        "maxAgeSeconds": 300,
        "acrValue": "sbos_aal3",
        "reauthRequired": true,
        "description": "Modificar roles de administrador, CFO o CEO requiere AAL3. Trazabilidad completa en audit log."
      },
      {
        "ruleId": "STEP-DATA-EXPORT",
        "trigger": "bulk_data_export",
        "condition": {
          "type": "THRESHOLD",
          "field": "record_count",
          "operator": ">",
          "value": 100,
          "description": "Exportar más de 100 registros dispara step-up"
        },
        "requiredLoa": 3,
        "maxAgeSeconds": 600,
        "acrValue": "sbos_aal3",
        "reauthRequired": true,
        "description": "Exportación masiva de datos requiere AAL3. Prevención de exfiltración de datos."
      },
      {
        "ruleId": "STEP-DELEGATION-CREATE",
        "trigger": "delegation_create",
        "condition": null,
        "requiredLoa": 3,
        "maxAgeSeconds": 60,
        "acrValue": "sbos_aal3_fresh",
        "reauthRequired": true,
        "description": "Crear una delegación de permisos requiere AAL3 fresco. El delegador debe probar su identidad."
      },
      {
        "ruleId": "STEP-SOD-OVERRIDE",
        "trigger": "sod_override",
        "condition": null,
        "requiredLoa": 3,
        "maxAgeSeconds": 0,
        "acrValue": "sbos_aal3_hw_key",
        "reauthRequired": true,
        "requiresJustification": true,
        "approvalRequired": true,
        "approverRoles": ["ROL-SYS-ADMIN-SEGURIDAD", "ROL-ORG-CCO"],
        "description": "Override de Segregación de Funciones requiere AAL3 con hardware key + justificación formal + aprobación dual."
      }
    ],
```

---

## 1.5 — `zones` — Zonas de Negocio con Verbos, Scope y Restricciones

**Propósito:** Define en qué zonas organizacionales opera el rol, con qué verbos (CRUD + extendidos),
bajo qué scope (GLOBAL→PERSONAL), con qué restricciones de datos (clasificación, PII, masking),
y qué aplicaciones implementan cada zona.

**Estándar:** OASIS XACML 3.0 (PEP/PIP/PDP/PEP) · NIST SP 800-162 ABAC · NIST 800-53 AC-3/AC-6

**Catálogo:** `log_zone` (29 áreas) · `privilege_verb` (50 verbos) · `privilege_atom` (5,808 átomos)

```json
    "zones": {
      "zone_logical/ventas": {
        "zoneCode": "AREA-VENT",
        "zoneName": {"es": "Ventas", "en": "Sales", "pt": "Vendas"},
        "category": "OPERATIVA",
        "isCritical": false,
        "verbs": ["READ", "WRITE", "APPROVE", "EXECUTE"],
        "scope": "REGIONAL",
        "scopeDescription": "Solo datos de la región asignada al usuario. Record Rule automática en Tryton.",
        "restrictions": {
          "maxRecordLimit": 1000,
          "dataClassification": ["PUBLIC", "INTERNAL", "CONFIDENTIAL"],
          "restrictedClassifications": ["RESTRICTED"],
          "piiAccess": true,
          "piiFields": ["party.name", "party.tax_identifier", "party.phone"],
          "maskingPolicy": "PARTIAL_MASK",
          "maskingRules": {
            "tax_identifier": "lastFourVisible",
            "phone": "lastFourVisible",
            "email": "domainOnly"
          }
        },
        "applications": [
          {
            "app": "tryton",
            "modules": ["sale", "sale_opportunity", "sale_pos", "party", "account_invoice"],
            "visibleMenus": [
              "menu_sale_orders", "menu_sale_opportunities", "menu_sale_pos",
              "menu_party_customers", "menu_account_invoice_view"
            ],
            "visibleActions": [
              "action_sale_order_form", "action_sale_opportunity_tree",
              "action_party_customer_tree", "action_invoice_tree"
            ],
            "hiddenFields": {
              "sale.order": ["margin", "cost_price", "commission_rate"],
              "sale.line": ["margin", "cost_price", "purchase_price"],
              "product.product": ["cost_price", "supplier_code", "warehouse_location"],
              "party.party": ["credit_limit", "internal_notes", "risk_score"],
              "account.invoice": ["margin", "cost_allocation", "internal_reference"]
            },
            "readonlyFields": {
              "sale.order": ["state", "create_date", "write_date"],
              "party.party": ["credit_limit"],
              "product.product": ["list_price"]
            }
          },
          {
            "app": "espocrm",
            "modules": ["sales", "contacts", "opportunities"],
            "visibleScopes": ["own", "team"]
          },
          {
            "app": "superset",
            "dashboards": ["ventas_regionales", "pipeline_ventas", "cumplimiento_cuotas"],
            "datasets": ["sale_order_aggregated", "customer_ltv", "sales_rep_performance"]
          }
        ],
        "recordRules": [
          {
            "app": "tryton",
            "model": "sale.order",
            "domainPyson": "[('shop.region', '=', Eval('context', {}).get('user_region', ''))]",
            "description": "Solo pedidos de la región asignada al usuario"
          },
          {
            "app": "tryton",
            "model": "sale.opportunity",
            "domainPyson": "[('responsible.id', 'in', [Eval('user.id', 0)] + [r.id for r in Eval('user.employee.subordinates', [])])]",
            "description": "Solo oportunidades propias o de subordinados directos"
          },
          {
            "app": "espocrm",
            "entity": "Opportunity",
            "whereClause": "assignedUserId = :currentUserId OR teams.id IN (:userTeamIds)",
            "description": "Solo oportunidades asignadas al usuario o a sus equipos"
          }
        ]
      },

      "zone_logical/facturacion": {
        "zoneCode": "AREA-FACT",
        "zoneName": {"es": "Facturación", "en": "Invoicing", "pt": "Faturamento"},
        "category": "OPERATIVA",
        "isCritical": true,
        "verbs": ["READ", "WRITE", "EMIT"],
        "scope": "REGIONAL",
        "restrictions": {
          "maxRecordLimit": 500,
          "dataClassification": ["INTERNAL", "CONFIDENTIAL"],
          "restrictedClassifications": ["RESTRICTED", "SECRET"],
          "piiAccess": false,
          "requiresSinDosificacion": true,
          "requiresCafc": true
        },
        "applications": [
          {
            "app": "tryton",
            "modules": ["account_invoice", "account_invoice_ar", "account_payment"],
            "visibleMenus": [
              "menu_account_invoice_tree", "menu_account_invoice_create",
              "menu_account_payment_tree", "menu_sin_dosificacion"
            ],
            "hiddenFields": {
              "account.invoice": ["margin", "cost_allocation", "internal_reference"],
              "account.invoice.line": ["cost_price", "margin"],
              "account.move": ["internal_note"]
            },
            "buttonRules": [
              {
                "model": "account.invoice",
                "button": "confirm",
                "conditionPyson": "Eval('amount_total', 0) <= 5000",
                "usersRequired": 1,
                "sodCannotAlso": null,
                "stepUpLoa": null
              },
              {
                "model": "account.invoice",
                "button": "confirm",
                "conditionPyson": "And(Eval('amount_total', 0) > 5000, Eval('amount_total', 0) <= 50000)",
                "usersRequired": 2,
                "sodCannotAlso": "account.invoice:create",
                "stepUpLoa": 3
              },
              {
                "model": "account.invoice",
                "button": "cancel",
                "conditionPyson": "Eval('state', '') == 'draft'",
                "usersRequired": 1,
                "sodCannotAlso": "account.invoice:create",
                "stepUpLoa": null
              },
              {
                "model": "account.invoice",
                "button": "post_sin",
                "conditionPyson": "Eval('state', '') == 'validated'",
                "usersRequired": 1,
                "sodCannotAlso": null,
                "stepUpLoa": 3,
                "description": "Envío a SIN Bolivia requiere AAL3"
              }
            ]
          },
          {
            "app": "paperless",
            "tags": ["factura", "nota_credito", "nota_debito", "dosificacion_sin"],
            "correspondentFilters": ["SIN_Bolivia"]
          }
        ],
        "recordRules": [
          {
            "app": "tryton",
            "model": "account.invoice",
            "domainPyson": "[('branch_id', '=', Eval('context', {}).get('user_branch_id', 0))]",
            "description": "Solo facturas de la sucursal asignada"
          }
        ]
      },

      "zone_logical/clientes": {
        "zoneCode": "AREA-CLI",
        "zoneName": {"es": "Clientes", "en": "Customers", "pt": "Clientes"},
        "category": "COMERCIAL",
        "isCritical": false,
        "verbs": ["READ", "WRITE"],
        "scope": "REGIONAL",
        "restrictions": {
          "maxRecordLimit": 2000,
          "dataClassification": ["CONFIDENTIAL"],
          "piiAccess": true,
          "piiFields": ["party.name", "party.tax_identifier", "party.phone", "party.email", "party.address"],
          "maskingPolicy": "FULL_MASK_ON_LIST",
          "gdprSensitive": true,
          "gdprLawfulBasis": "legitimate_interest",
          "gdprRetentionDays": 365
        },
        "applications": [
          {
            "app": "tryton",
            "modules": ["party", "party_relationship", "marketing_campaign"],
            "hiddenFields": {
              "party.party": ["credit_limit", "credit_score", "internal_rating", "risk_category"]
            }
          },
          {
            "app": "espocrm",
            "modules": ["contacts", "accounts"],
            "visibleScopes": ["own", "team"]
          }
        ]
      },

      "zone_logical/reportes": {
        "zoneCode": "AREA-REP",
        "zoneName": {"es": "Reportes", "en": "Reports", "pt": "Relatórios"},
        "category": "ADMINISTRATIVA",
        "isCritical": false,
        "verbs": ["READ", "EXECUTE"],
        "scope": "REGIONAL",
        "restrictions": {
          "maxRecordLimit": 5000,
          "dataClassification": ["PUBLIC", "INTERNAL", "CONFIDENTIAL"],
          "piiAccess": false,
          "noDataExport": true,
          "noDataDownload": false
        },
        "applications": [
          {
            "app": "superset",
            "dashboards": [
              "ventas_diarias", "facturacion_mensual", "cobranza_pendiente",
              "comisiones_vendedores", "clientes_nuevos"
            ],
            "datasets": [
              "sale_order_aggregated", "invoice_aggregated",
              "payment_collection_status", "sales_commission_calculation"
            ],
            "rowLevelSecurity": {
              "sale_order_aggregated": "region_id = {{user.region_id}}",
              "invoice_aggregated": "branch_id = {{user.branch_id}}"
            }
          },
          {
            "app": "tryton",
            "modules": ["account_statement", "account_reporting"],
            "visibleActions": ["action_report_sales_summary", "action_report_invoice_summary"]
          }
        ]
      }
    },
```

---

## 1.6 — `trytonPrivileges` — 5 Capas Nativas de Enforcement

**Propósito:** Definición EXPLÍCITA y exhaustiva de cada capa de enforcement en Tryton. bAuth
genera estos objetos automáticamente al sincronizar. Este bloque es la TRADUCCIÓN DIRECTA del
RolTemplate a objetos nativos de Tryton.

**Estándar:** Tryton 7.x ir.model.access · ir.rule · ir.model.button · ir.action.groups

```json
    "trytonPrivileges": {
      "modelAccess": [
        {"model": "sale.order",           "read": true,  "write": true,  "create": true,  "delete": false},
        {"model": "sale.opportunity",     "read": true,  "write": true,  "create": true,  "delete": false},
        {"model": "sale.line",            "read": true,  "write": true,  "create": true,  "delete": false},
        {"model": "sale.pos",             "read": true,  "write": true,  "create": true,  "delete": false},
        {"model": "sale.pos.order",       "read": true,  "write": true,  "create": true,  "delete": false},
        {"model": "party.party",          "read": true,  "write": true,  "create": true,  "delete": false},
        {"model": "party.address",        "read": true,  "write": true,  "create": true,  "delete": false},
        {"model": "party.contact_mechanism","read":true, "write": true,  "create": true,  "delete": false},
        {"model": "account.invoice",      "read": true,  "write": false, "create": true,  "delete": false},
        {"model": "account.invoice.line", "read": true,  "write": false, "create": true,  "delete": false},
        {"model": "account.payment",      "read": true,  "write": true,  "create": true,  "delete": false},
        {"model": "account.move",         "read": true,  "write": false, "create": false, "delete": false},
        {"model": "account.move.line",    "read": true,  "write": false, "create": false, "delete": false},
        {"model": "product.product",      "read": true,  "write": false, "create": false, "delete": false},
        {"model": "product.template",     "read": true,  "write": false, "create": false, "delete": false},
        {"model": "product.category",     "read": true,  "write": false, "create": false, "delete": false},
        {"model": "stock.shipment.out",   "read": true,  "write": false, "create": false, "delete": false},
        {"model": "stock.shipment.in",    "read": true,  "write": false, "create": false, "delete": false},
        {"model": "purchase.order",       "read": false, "write": false, "create": false, "delete": false},
        {"model": "purchase.line",        "read": false, "write": false, "create": false, "delete": false},
        {"model": "company.employee",     "read": true,  "write": false, "create": false, "delete": false},
        {"model": "res.user",             "read": false, "write": false, "create": false, "delete": false},
        {"model": "ir.model",             "read": false, "write": false, "create": false, "delete": false},
        {"model": "ir.rule",              "read": false, "write": false, "create": false, "delete": false},
        {"model": "ir.model.access",      "read": false, "write": false, "create": false, "delete": false}
      ],

      "visibleActions": [
        "menu_sale_orders",
        "menu_sale_pos",
        "menu_sale_opportunities",
        "menu_sale_products",
        "menu_sale_reports_regional",
        "menu_party_customers",
        "menu_party_addresses",
        "menu_account_invoice_view",
        "menu_account_invoice_create",
        "menu_account_payment_view",
        "menu_dashboard_ventas",
        "menu_stock_shipment_out_view",
        "action_sale_order_form",
        "action_sale_pos_form",
        "action_party_customer_tree",
        "action_invoice_tree",
        "action_invoice_form",
        "action_payment_tree",
        "action_report_sales_summary",
        "action_report_invoice_summary",
        "wizard_create_invoice_from_sale",
        "wizard_sale_pos_close_shift"
      ],

      "visibleButtons": [
        {"model": "sale.order", "buttons": ["confirm", "quote", "cancel", "draft"]},
        {"model": "sale.pos.order", "buttons": ["pay", "return", "void", "print_receipt"]},
        {"model": "account.invoice", "buttons": ["validate", "post", "cancel", "draft"]},
        {"model": "account.payment", "buttons": ["approve", "reject", "reconcile"]}
      ],

      "fieldOverrides": [
        {"model": "account.invoice", "field": "margin",         "read": false, "write": false},
        {"model": "account.invoice", "field": "cost_price",     "read": false, "write": false},
        {"model": "account.invoice", "field": "commission_rate","read": false, "write": false},
        {"model": "sale.order",      "field": "margin",         "read": false, "write": false},
        {"model": "sale.order",      "field": "cost_price",     "read": false, "write": false},
        {"model": "sale.order",      "field": "commission_rate","read": false, "write": false},
        {"model": "sale.line",       "field": "margin",         "read": false, "write": false},
        {"model": "sale.line",       "field": "cost_price",     "read": false, "write": false},
        {"model": "sale.line",       "field": "purchase_price", "read": false, "write": false},
        {"model": "party.party",     "field": "credit_limit",   "read": true,  "write": false},
        {"model": "party.party",     "field": "credit_score",   "read": false, "write": false},
        {"model": "party.party",     "field": "internal_rating","read": false, "write": false},
        {"model": "party.party",     "field": "risk_category",  "read": false, "write": false},
        {"model": "product.product", "field": "cost_price",     "read": false, "write": false},
        {"model": "product.product", "field": "supplier_code",  "read": false, "write": false},
        {"model": "product.product", "field": "warehouse_location","read":false,"write":false},
        {"model": "product.template","field": "purchase_price", "read": false, "write": false}
      ],

      "buttonRules": [
        {
          "model": "sale.order",
          "button": "confirm",
          "conditionPyson": "Eval('amount_total', 0) <= 5000",
          "usersRequired": 1,
          "sodCannotAlso": null,
          "stepUpLoa": null,
          "notificationChannels": [],
          "description": "Confirmar venta ≤ 5.000 BOB — un solo usuario, sin step-up"
        },
        {
          "model": "sale.order",
          "button": "confirm",
          "conditionPyson": "And(Eval('amount_total', 0) > 5000, Eval('amount_total', 0) <= 50000)",
          "usersRequired": 2,
          "sodCannotAlso": "sale.order:create",
          "stepUpLoa": 3,
          "notificationChannels": ["rocket_chat", "email"],
          "description": "Confirmar venta 5.001–50.000 — requiere 2 aprobadores + WebAuthn + SoD activo"
        },
        {
          "model": "sale.order",
          "button": "cancel",
          "conditionPyson": "Eval('state', '') == 'draft'",
          "usersRequired": 1,
          "sodCannotAlso": "sale.order:create",
          "stepUpLoa": null,
          "description": "Cancelar venta en borrador — quien la creó no puede cancelarla (SoD)"
        },
        {
          "model": "account.invoice",
          "button": "post_sin",
          "conditionPyson": "Eval('state', '') == 'validated'",
          "usersRequired": 1,
          "sodCannotAlso": "account.invoice:create",
          "stepUpLoa": 3,
          "notificationChannels": ["rocket_chat"],
          "description": "Envío a SIN Bolivia — requiere AAL3 + SoD (quien crea no envía)"
        },
        {
          "model": "account.payment",
          "button": "approve",
          "conditionPyson": "Eval('amount', 0) > 5000",
          "usersRequired": 2,
          "sodCannotAlso": "account.payment:create",
          "stepUpLoa": 3,
          "notificationChannels": ["rocket_chat", "email"],
          "description": "Aprobar pago > 5.000 BOB — SoD activo + AAL3 + 2 aprobadores"
        },
        {
          "model": "sale.pos.order",
          "button": "void",
          "conditionPyson": "Eval('state', '') == 'posted'",
          "usersRequired": 1,
          "sodCannotAlso": "sale.pos.order:create",
          "stepUpLoa": null,
          "notificationChannels": ["rocket_chat"],
          "description": "Anular ticket de caja — SoD (quien cobró no puede anular) + notificación a gerencia"
        }
      ],

      "recordRules": [
        {
          "model": "sale.order",
          "domainPyson": "[('shop.region', '=', Eval('context', {}).get('user_region', ''))]",
          "permWriteException": false,
          "description": "Solo pedidos de la región asignada"
        },
        {
          "model": "sale.opportunity",
          "domainPyson": "[('responsible.id', 'in', [Eval('user.id', 0)] + [r.id for r in Eval('user.employee.subordinates', [])])]",
          "permWriteException": true,
          "description": "Oportunidades propias y de subordinados directos"
        },
        {
          "model": "party.party",
          "domainPyson": "[('category', 'in', ['CUSTOMER', 'PROSPECT'])]",
          "permWriteException": false,
          "description": "Solo clientes y prospectos — excluye empleados, proveedores, internos"
        },
        {
          "model": "account.invoice",
          "domainPyson": "[('branch_id', '=', Eval('context', {}).get('user_branch_id', 0))]",
          "permWriteException": false,
          "description": "Solo facturas de la sucursal del usuario"
        }
      ]
    },
```

---

## 1.7 — `temporalControl` y `sessionManagement`

**Propósito:** Control horario y de sesión acoplado al dominio lógico. Define cuándo y por cuánto
tiempo el rol puede tener sesiones digitales activas.

**Estándar:** GTRBAC · NIST SP 800-63B-4 §7 · RFC 5545

```json
    "temporalControl": {
      "enabled": true,
      "scheduleType": "SPECIFIC_DAYS",
      "timezone": "America/La_Paz",
      "allowedDays": [
        {"day": "MONDAY",    "shifts": [{"start": "08:00", "end": "12:00"}, {"start": "14:00", "end": "18:00"}]},
        {"day": "TUESDAY",   "shifts": [{"start": "08:00", "end": "12:00"}, {"start": "14:00", "end": "18:00"}]},
        {"day": "WEDNESDAY", "shifts": [{"start": "08:00", "end": "12:00"}, {"start": "14:00", "end": "18:00"}]},
        {"day": "THURSDAY",  "shifts": [{"start": "08:00", "end": "12:00"}, {"start": "14:00", "end": "18:00"}]},
        {"day": "FRIDAY",    "shifts": [{"start": "08:00", "end": "15:00"}]}
      ],
      "exceptions": {
        "holidays": "BLOCKED",
        "holidayCalendarId": "uuid-bolivia-holidays",
        "specialDates": [
          {"date": "2026-02-01", "status": "BLOCKED", "reason": "Inventario Anual Obligatorio"},
          {"date": "2026-03-15", "status": "ALLOWED", "reason": "Jornada Especial de Ventas"}
        ],
        "emergencyOverride": {
          "allowed": true,
          "requiresApproval": true,
          "approverRoles": ["ROL-ORG-GER-VENT", "ROL-SYS-ADMIN-SEGURIDAD"],
          "maxDurationHours": 4,
          "auditLogging": "comprehensive",
          "documentationRequired": true
        }
      }
    },

    "sessionManagement": {
      "maxSessionDurationSeconds": 28800,
      "inactivityTimeoutSeconds": 900,
      "forceLogoutAtEndShift": true,
      "concurrentSessionsAllowed": false,
      "maxConcurrentSessions": 1,
      "reauthenticationIntervalSeconds": 14400,
      "tokenBinding": {
        "bindToDevice": true,
        "bindToIp": false,
        "bindToUserAgent": true,
        "requireDpop": false
      },
      "sessionTerminationTriggers": [
        "END_SHIFT",
        "INACTIVITY_TIMEOUT",
        "FORCED_LOGOUT_BY_ADMIN",
        "DEVICE_COMPROMISE",
        "CRITICAL_RISK_DETECTED",
        "PASSWORD_CHANGE",
        "ROLE_CHANGE"
      ]
    }
  }
}
```

---

## RESUMEN — Sección D1 `logical_access`

| Sub-bloque | Campos | Propósito |
|-----------|:---:|---|
| `availableMethods` | 14 métodos × 20 atributos c/u | Catálogo completo de métodos digitales con LoA, phishing resistance, device binding |
| `requiredMethods` | 8 flujos × N factores | Orquestación de factores por contexto de acceso |
| `alternativeMethods` | 6 alternativas | Resiliencia ante fallo de método primario |
| `levelOfAssurance` + `stepUpRules` | 1 LoA + 6 reglas | Elevación condicional de seguridad vía RFC 9470 |
| `zones` | 4 zonas × ~30 atributos | Zonas de negocio con verbos, scope, apps, hidden fields, button rules, record rules |
| `trytonPrivileges` | 5 capas nativas | modelAccess (25 modelos) + visibleActions (22) + visibleButtons (4) + fieldOverrides (17) + buttonRules (6) + recordRules (4) |
| `temporalControl` | 5 días + excepciones + emergencies | Cuándo el rol puede operar digitalmente |
| `sessionManagement` | 11 atributos | Control de sesiones con binding, termination triggers |

**Total: ~300 atributos en la sección D1.** Compárese con los 9 atributos de la v2.0.

---

*¿Continúo con D2 (Físico) con este mismo nivel de profundidad?*
# BAUTH-ROLTEMPLATE-SECCIONES v6.0 — Secciones D2 a D14

**Continuación de BAUTH-ROLTEMPLATE-SECCIONES.md**
**Versión:** 6.0 · **Fecha:** 2026-06-24

---

# SECCIÓN 2 — `physical_access` (D2 — FÍSICO)

**Dominio:** D2 — Físico · **Tipo:** Fast-Path · **Orden evaluación:** 5° (D8→D9→D1→D3→D2→...)

**Propósito integral:** Controla el acceso del rol a espacios físicos, zonas de seguridad, dispositivos
y actuadores. Define qué métodos de acceso físico se requieren (NFC, QR, biométrico, smartcard), con
qué nivel de seguridad por tipo de zona, políticas anti-passback, enrolamiento biométrico, control de
emergencia física, y reglas de dos personas.

**Estándar:** IEC 60839-11-5 · SIA OSDP v2.2.3 · NIST SP 800-116 PIV · NIST SP 800-53 PE-2/PE-3
  · ISO 27001:2022 A.7.1–A.7.7

**Catálogo:** `fis_location` · `fis_access_zone` · `fis_device` · `fis_perimeter`

```json
{
  "physical_access": {
    "enabled": true,

    "availableMethods": [
      {
        "methodId": "QR_DYNAMIC",
        "methodName": "QR Dinámico HMAC-SHA256",
        "loaMin": 2,
        "loaMax": 2,
        "category": "DIGITAL",
        "standard": "HMAC-SHA256 TTL 30s",
        "ttl_seconds": 30,
        "is_ephemeral": true,
        "requires_smartphone": true,
        "fallback_for": ["BIOMETRIC_FAIL", "NFC_LOST", "SMARTCARD_LOST"],
        "max_uses_per_day": 20,
        "description": "QR regenerado cada 30s vía app SBOS Authenticator. El QR cambia visualmente en cada ciclo."
      },
      {
        "methodId": "NFC_MIFARE_DESFIRE",
        "methodName": "NFC MIFARE DESFire EV3",
        "loaMin": 2,
        "loaMax": 3,
        "category": "CONTACTLESS",
        "standard": "ISO 14443-A · AES-128 · MIFARE DESFire EV3",
        "chip_type": "DESFire_EV3",
        "encryption": "AES-128",
        "key_diversification": true,
        "anti_cloning": true,
        "max_keys_per_card": 32,
        "description": "Tarjeta NFC de alta seguridad con cifrado AES-128. Anticloning vía firma criptográfica en chip. LoA 2-3."
      },
      {
        "methodId": "NFC_MIFARE_CLASSIC",
        "methodName": "NFC MIFARE Classic (Legacy)",
        "loaMin": 1,
        "loaMax": 1,
        "category": "CONTACTLESS",
        "standard": "ISO 14443-A (legacy) · Crypto-1 (vulnerable)",
        "chip_type": "MIFARE_Classic_1K",
        "encryption": "CRYPTO1",
        "key_diversification": false,
        "anti_cloning": false,
        "deprecated": true,
        "deprecation_target": "2028-01-01",
        "description": "⚠️ DEPRECADO. Crypto-1 es vulnerable a clonación y ataques de cifrado. Solo mantener para tarjetas legacy existentes. Migrar a DESFire EV3."
      },
      {
        "methodId": "RFID_125KHZ",
        "methodName": "RFID 125 KHz Proximity (Wiegand)",
        "loaMin": 1,
        "loaMax": 1,
        "category": "PROXIMITY",
        "standard": "Wiegand 26-bit · EM4100 (legacy)",
        "encryption": "NONE",
        "anti_cloning": false,
        "deprecated": true,
        "deprecation_target": "2027-01-01",
        "description": "⚠️ ALTAMENTE DEPRECADO. Sin cifrado, clonable con dispositivo de $20. Solo para puertas de zonas públicas legacy. Reemplazo urgente por DESFire."
      },
      {
        "methodId": "FINGERPRINT_HASH",
        "methodName": "Hash de Huella Dactilar",
        "loaMin": 3,
        "loaMax": 4,
        "category": "BIOMETRIC",
        "standard": "ISO/IEC 19794-2 · ISO/IEC 30107-3 PAD",
        "biometric_type": "FINGERPRINT",
        "hash_algorithm": "Argon2id",
        "template_storage": "HASH_ONLY",
        "liveness_required": true,
        "liveness_method": "PASSIVE",
        "fmr_threshold": "1:10000",
        "max_failed_attempts": 3,
        "fallback_method": "QR_DYNAMIC",
        "description": "Hash Argon2id del template de huella. NUNCA se almacena la imagen/huella raw. Liveness pasiva obligatoria. FMR ≤ 1:10,000 (NIST)."
      },
      {
        "methodId": "FACE_HASH",
        "methodName": "Hash de Reconocimiento Facial 3D",
        "loaMin": 3,
        "loaMax": 4,
        "category": "BIOMETRIC",
        "standard": "ISO/IEC 19794-5 · ISO/IEC 30107-3 PAD",
        "biometric_type": "FACE_3D",
        "hash_algorithm": "Argon2id",
        "template_storage": "HASH_ONLY",
        "liveness_required": true,
        "liveness_method": "ACTIVE",
        "liveness_challenge": "RANDOM_HEAD_MOVEMENT",
        "fmr_threshold": "1:100000",
        "max_failed_attempts": 2,
        "fallback_method": "FINGERPRINT_HASH",
        "description": "Hash 3D facial con desafío de movimiento aleatorio (ACTIVE liveness). Para zonas de máxima seguridad."
      },
      {
        "methodId": "IRIS_HASH",
        "methodName": "Hash de Iris",
        "loaMin": 4,
        "loaMax": 4,
        "category": "BIOMETRIC",
        "standard": "ISO/IEC 19794-6 · ISO/IEC 30107-3 PAD",
        "biometric_type": "IRIS",
        "hash_algorithm": "Argon2id",
        "template_storage": "HASH_ONLY",
        "liveness_required": true,
        "liveness_method": "COMBINED",
        "fmr_threshold": "1:1000000",
        "max_failed_attempts": 2,
        "fallback_method": "FACE_HASH",
        "description": "Hash de iris con liveness combinada (pasiva + activa). FMR ≤ 1:1,000,000. Uso: data centers, bóvedas, salas de armas."
      },
      {
        "methodId": "SMARTCARD_X509",
        "methodName": "Smart Card X.509 PIV/CAC",
        "loaMin": 3,
        "loaMax": 4,
        "category": "PKI",
        "standard": "FIPS 201-3 PIV · NIST SP 800-73-5 · ISO 7816",
        "certificate_format": "X.509v3",
        "key_algorithm": "RSA-2048 / ECDSA-P256",
        "chip_interface": "CONTACT",
        "requires_pin": true,
        "pin_min_length": 6,
        "pin_max_attempts": 3,
        "anti_tearing": true,
        "description": "Tarjeta inteligente con chip criptográfico. PIN de 6 dígitos. Bloqueo tras 3 intentos fallidos. Uso: gobierno, defensa, financiero crítico."
      },
      {
        "methodId": "PIN_PAD",
        "methodName": "PIN Pad (Nunca como único factor)",
        "loaMin": 1,
        "loaMax": 1,
        "category": "KNOWLEDGE",
        "standard": "ISO 9564 · NIST SP 800-53 IA-5",
        "min_length": 4,
        "max_length": 8,
        "max_attempts": 5,
        "can_be_primary": false,
        "must_be_combined_with": ["NFC_MIFARE_DESFIRE", "FINGERPRINT_HASH"],
        "description": "PIN físico. NUNCA como único factor. Siempre combinado con tarjeta o biométrico (algo que tienes + algo que sabes)."
      }
    ],

    "requiredMethods": {
      "public_areas": [
        {"methodId": "QR_DYNAMIC", "order": 1, "loa": 2}
      ],
      "employee_areas": [
        {"methodId": "NFC_MIFARE_DESFIRE", "order": 1, "loa": 2}
      ],
      "restricted_areas": [
        {"methodId": "NFC_MIFARE_DESFIRE", "order": 1, "loa": 2},
        {"methodId": "FINGERPRINT_HASH",   "order": 2, "loa": 3}
      ],
      "critical_areas": [
        {"methodId": "SMARTCARD_X509",    "order": 1, "loa": 4},
        {"methodId": "FINGERPRINT_HASH",  "order": 2, "loa": 3}
      ],
      "maximum_security_areas": [
        {"methodId": "SMARTCARD_X509",    "order": 1, "loa": 4},
        {"methodId": "IRIS_HASH",         "order": 2, "loa": 4}
      ]
    },

    "zones": [
      {
        "zoneId": "PHY_ZONE_LOBBY",
        "zoneName": {"es": "Vestíbulo y Recepción", "en": "Lobby & Reception"},
        "securityLevel": 1,
        "category": "PUBLIC",
        "accessLevel": "FULL",
        "schedule": "24x7",
        "maxOccupancy": 50,
        "accessPoints": ["AP-RECEPCION-01", "AP-TORNIQUETE-01"],
        "devices": [
          {"deviceId": "DEV-TORN-01", "type": "TURNSTILE", "protocol": "OSDP", "direction": "BIDIRECTIONAL"}
        ],
        "requiresEscort": false,
        "requiresTwoPerson": false,
        "requiresMantrap": false
      },
      {
        "zoneId": "PHY_ZONE_VENTAS",
        "zoneName": {"es": "Piso de Ventas — Planta Baja", "en": "Sales Floor — Ground Floor"},
        "securityLevel": 2,
        "category": "EMPLOYEE",
        "accessLevel": "FULL",
        "schedule": "business_hours",
        "maxOccupancy": 30,
        "accessPoints": ["AP-VENTAS-01", "AP-VENTAS-02", "AP-CAJA-01"],
        "devices": [
          {"deviceId": "DEV-LECTOR-01", "type": "CARD_READER", "protocol": "OSDP", "supportedMethods": ["NFC_MIFARE_DESFIRE", "NFC_MIFARE_CLASSIC"]},
          {"deviceId": "DEV-CAM-VEN-01", "type": "IP_CAMERA", "protocol": "ONVIF", "resolution": "4K", "fps": 30}
        ],
        "requiresEscort": false,
        "requiresTwoPerson": false,
        "requiresMantrap": false,
        "antiPassback": {
          "enabled": true,
          "mode": "SOFT",
          "resetHours": 24,
          "description": "Soft anti-passback: permite entrada sin salida previa pero alerta a seguridad"
        }
      },
      {
        "zoneId": "PHY_ZONE_CAJA",
        "zoneName": {"es": "Área de Cajas y Valores", "en": "Cashier & Valuables Area"},
        "securityLevel": 3,
        "category": "RESTRICTED",
        "accessLevel": "FULL",
        "schedule": "business_hours",
        "maxOccupancy": 5,
        "accessPoints": ["AP-CAJA-01", "AP-BOVEDA-01"],
        "devices": [
          {"deviceId": "DEV-LECTOR-CAJ-01", "type": "CARD_READER", "protocol": "OSDP", "supportedMethods": ["NFC_MIFARE_DESFIRE"]},
          {"deviceId": "DEV-BIO-CAJ-01", "type": "BIOMETRIC_READER", "protocol": "OSDP", "supportedMethods": ["FINGERPRINT_HASH"]},
          {"deviceId": "DEV-CAM-CAJ-01", "type": "PTZ_CAMERA", "protocol": "ONVIF", "resolution": "4K", "fps": 60, "retention_days": 90},
          {"deviceId": "DEV-ALM-CAJ-01", "type": "ALARM_SIREN", "protocol": "OSDP", "triggers": ["FORCED_ENTRY", "TAILGATING", "DURESS_CODE_ENTERED"]}
        ],
        "requiresEscort": false,
        "requiresTwoPerson": false,
        "requiresMantrap": false,
        "maxDurationMinutes": 480,
        "antiPassback": {
          "enabled": true,
          "mode": "HARD",
          "resetHours": 24,
          "description": "Hard anti-passback: bloquea físicamente entrada sin salida previa registrada"
        },
        "alarmOn": ["TAILGATING", "FORCED_ENTRY", "DURESS_CODE", "MAX_DURATION_EXCEEDED"]
      },
      {
        "zoneId": "PHY_ZONE_SERVIDOR",
        "zoneName": {"es": "Sala de Servidores — Data Center", "en": "Server Room — Data Center"},
        "securityLevel": 4,
        "category": "CRITICAL",
        "accessLevel": "DENIED",
        "reason": "Este rol no tiene acceso a la sala de servidores. Solo administradores de infraestructura."
      }
    ],

    "maxSecurityZone": 3,

    "physicalSecurityControls": {
      "twoPersonRule": false,
      "twoPersonRuleZones": [],
      "mantrapRequired": false,
      "mantrapZones": [],
      "escortRequiredFor": [],
      "antiPassbackGlobal": {
        "enabled": true,
        "defaultMode": "SOFT",
        "resetHours": 24
      },
      "duressCode": {
        "enabled": true,
        "codeType": "ALTERNATE_PIN",
        "silentAlarm": true,
        "notifySecurity": true,
        "notifyPolice": false,
        "lockdownZone": true
      }
    },

    "biometricEnrollmentPolicy": {
      "mode": "HYBRID",
      "riskLevel": "MEDIUM",
      "supervisorRequired": true,
      "dualEnrollment": false,
      "livenessRequired": true,
      "livenessMethod": "PASSIVE",
      "fallbackMethod": "QR_DYNAMIC",
      "maxFailedAttempts": 3,
      "hashAlgorithm": "Argon2id",
      "argon2Params": {
        "timeCost": 3,
        "memoryMb": 64,
        "parallelism": 2,
        "saltLength": 16,
        "hashLength": 32
      },
      "fmrThreshold": "1:10000",
      "enrollmentStations": ["PHY_ZONE_CAJA"],
      "gdprCompliance": {
        "requiresExplicitConsent": true,
        "consentRevocable": true,
        "dataRetentionDays": 365,
        "rightToDeletion": true,
        "processingPurpose": "ACCESS_CONTROL",
        "legalBasis": "EXPLICIT_CONSENT",
        "dataEncryptedAtRest": true,
        "crossBorderTransfer": false
      }
    },

    "emergencyOverride": {
      "allowed": false,
      "requiresApproval": true,
      "approverRoles": ["ROL-ORG-DIR-IT", "ROL-SYS-ADMIN-SEGURIDAD"],
      "maxDurationMinutes": 30,
      "auditLogging": "COMPREHENSIVE",
      "documentationRequired": true,
      "triggers": [
        {"trigger": "FIRE_ALARM", "action": "UNLOCK_ALL", "overrideMode": "EMERGENCY_EVACUATION"},
        {"trigger": "MEDICAL_EMERGENCY", "action": "UNLOCK_SPECIFIC_ZONE", "overrideMode": "TEMPORARY_ACCESS"},
        {"trigger": "SECURITY_BREACH", "action": "LOCKDOWN_ALL", "overrideMode": "LOCKDOWN"},
        {"trigger": "POWER_OUTAGE", "action": "FAIL_SAFE_UNLOCK", "overrideMode": "EMERGENCY_EGRESS"}
      ]
    }
  }
}
```

---

# SECCIÓN 3 — `financial_limits` (D3 — FINANCIERO)

**Dominio:** D3 — Financiero · **Tipo:** Policy-Path · **Orden evaluación:** 4°

**Propósito:** Control exhaustivo de operaciones financieras: límites multi-período, tipos de
transacción con controles, SoD formal, cadena de aprobación por monto, horario de transacciones,
métodos de autenticación financiera adicionales, control geoespacial financiero, y override de emergencia.

**Estándar:** PCI DSS 4.0.1 Req.7/8/10 · SOX §404 · COSO 2013/2023 · ISO 20022
  · NIST SP 800-53 AC-5 SoD · ISACA COBIT 2019 · SIN Bolivia RND 102100000011

**Catálogo:** `fin_transaction_type` (20 tipos) · `fin_limit` · `fin_approval`

```json
{
  "financial_limits": {
    "enabled": true,

    "availableMethods": [
      {"methodId": "TOTP",               "purpose": "Segundo factor para transacciones estándar", "required": true},
      {"methodId": "WEBAUTHN_PWDLESS",   "purpose": "Phishing-resistant para transacciones alto valor", "required": true},
      {"methodId": "SMARTCARD_X509",     "purpose": "Firma digital para transacciones críticas", "required": false},
      {"methodId": "MOBILE_TOKEN",       "purpose": "Token desacoplado en app móvil para aprobación remota", "required": false},
      {"methodId": "BIOMETRIC_VALIDATION","purpose": "Validación biométrica para anti-repudio de alto valor", "required": false},
      {"methodId": "HARDWARE_TOKEN",     "purpose": "Token hardware FIPS para operaciones de tesorería", "required": false}
    ],

    "transactionTypes": [
      {
        "code": "FAC_EMITIR",
        "name": {"es": "Emitir Factura", "en": "Issue Invoice"},
        "category": "VENTAS",
        "riskLevel": "ALTO",
        "controls": {
          "requiresDosificacionSin": true,
          "requiresCafc": true,
          "sinWebService": "produccion",
          "requiresCustomerTaxId": true,
          "validateTaxIdOnline": true,
          "maxItemsPerInvoice": 200,
          "blockCreditHoldCustomers": true,
          "autoCalculateTaxes": true,
          "taxRegime": "RND_102100000011"
        },
        "standardLimit": {"amount": 2000, "currency": "BOB", "period": "PER_TRANSACTION"},
        "requiresDualApproval": false,
        "requiresStepUp": false
      },
      {
        "code": "FAC_ANULAR",
        "name": {"es": "Anular Factura", "en": "Void Invoice"},
        "category": "VENTAS",
        "riskLevel": "CRITICO",
        "controls": {
          "requiresJustification": true,
          "justificationMinChars": 50,
          "requiresSinCancellation": true,
          "sinWebService": "produccion",
          "blockAfterDays": 3,
          "requiresSupervisorAuth": true,
          "notifyCompliance": true
        },
        "standardLimit": {"amount": 1000, "currency": "BOB", "period": "PER_TRANSACTION"},
        "requiresDualApproval": true,
        "requiresStepUp": true,
        "stepUpLoa": 3
      },
      {
        "code": "COBRO_RECIBIR",
        "name": {"es": "Recibir Cobro de Cliente", "en": "Receive Customer Payment"},
        "category": "COBROS",
        "riskLevel": "MEDIO",
        "controls": {
          "maxEfectivoBob": 50000,
          "maxEfectivoUsd": 10000,
          "verificarBilleteFalso": true,
          "requireComprobanteIngreso": true,
          "validateCustomerExists": true,
          "blockOverdueCustomers": true
        },
        "standardLimit": {"amount": 5000, "currency": "BOB", "period": "PER_TRANSACTION"},
        "requiresDualApproval": false,
        "requiresStepUp": false
      },
      {
        "code": "NC_EMITIR",
        "name": {"es": "Emitir Nota de Crédito", "en": "Issue Credit Note"},
        "category": "VENTAS",
        "riskLevel": "ALTO",
        "controls": {
          "requiresOriginalInvoice": true,
          "requiresMotivo": true,
          "maxPercentOfOriginal": 100,
          "requiresSinNotificacion": true,
          "motivosValidos": ["DEVOLUCION_MERCANCIA", "ERROR_FACTURACION", "DESCUENTO_POSTERIOR", "ANULACION_PARCIAL", "RESCISION_CONTRATO"]
        },
        "standardLimit": {"amount": 2000, "currency": "BOB", "period": "PER_TRANSACTION"},
        "requiresDualApproval": true,
        "requiresStepUp": false
      },
      {
        "code": "APERTURA_CAJA",
        "name": {"es": "Apertura de Caja", "en": "Open Cash Register"},
        "category": "COBROS",
        "riskLevel": "MEDIO",
        "controls": {
          "declareMontoInicial": true,
          "validateBilletes": true,
          "registerSerialNumbers": true,
          "cameraSnapshotRequired": true,
          "assignUniqueShiftId": true,
          "maxShiftDurationHours": 10,
          "requiresSupervisorIfLate": true,
          "lateThresholdMinutes": 15
        },
        "standardLimit": {"amount": 0, "currency": "BOB", "period": "PER_TRANSACTION"},
        "requiresDualApproval": false,
        "requiresStepUp": false
      },
      {
        "code": "CIERRE_CAJA",
        "name": {"es": "Cierre de Caja", "en": "Close Cash Register"},
        "category": "COBROS",
        "riskLevel": "ALTO",
        "controls": {
          "cuadreObligatorio": true,
          "maxDiferenciaBob": 100,
          "diferenciaExcedidaAction": "BLOQUEAR_CIERRE",
          "requiresArqueoPrint": true,
          "depositoBancoObligatorio": true,
          "depositoMaxHoursPostCierre": 24,
          "requiresSupervisorSignature": true,
          "cameraSnapshotRequired": true
        },
        "standardLimit": {"amount": 0, "currency": "BOB", "period": "PER_TRANSACTION"},
        "requiresDualApproval": true,
        "requiresStepUp": true,
        "stepUpLoa": 3
      }
    ],

    "transactionLimits": {
      "currency": "BOB",
      "perTransactionLimit": 2000,
      "dailyLimit": 10000,
      "weeklyLimit": 40000,
      "monthlyLimit": 50000,
      "perPeriodLimit": 25000,
      "annualLimit": 500000,
      "requiresDualApprovalAbove": 5000,
      "limitAggregation": "SUM_ALL_TRANSACTIONS",
      "aggregationScope": "PER_USER",
      "resetCron": "daily at 00:00 America/La_Paz"
    },

    "approvalChain": {
      "levels": [
        {
          "tier": 1,
          "amountUpTo": 2000,
          "approversRequired": 1,
          "approverRoles": ["ROL-ORG-GER-VENT"],
          "timeoutHours": 4,
          "escalationRole": "ROL-ORG-CCO"
        },
        {
          "tier": 2,
          "amountUpTo": 10000,
          "approversRequired": 2,
          "approverRoles": ["ROL-ORG-GER-VENT", "ROL-ORG-DIR-FIN"],
          "timeoutHours": 2,
          "escalationRole": "ROL-ORG-CFO",
          "requireStepUp": true,
          "stepUpLoa": 3
        },
        {
          "tier": 3,
          "amountUpTo": 50000,
          "approversRequired": 3,
          "approverRoles": ["ROL-ORG-GER-VENT", "ROL-ORG-DIR-FIN", "ROL-ORG-CFO"],
          "timeoutHours": 1,
          "escalationRole": "ROL-ORG-CEO",
          "requireStepUp": true,
          "stepUpLoa": 3,
          "requireJustification": true
        },
        {
          "tier": 4,
          "amountUpTo": null,
          "approversRequired": 4,
          "approverRoles": ["ROL-ORG-GER-VENT", "ROL-ORG-DIR-FIN", "ROL-ORG-CFO", "ROL-ORG-CEO"],
          "timeoutHours": 1,
          "escalationRole": "ROL-SYS-SUPERUSUARIO",
          "requireStepUp": true,
          "stepUpLoa": 4,
          "requireJustification": true,
          "requireBoardNotification": true
        }
      ]
    },

    "sodRules": [
      {
        "ruleId": "SOD-FAC-CREATE-APPROVE",
        "actionA": "FAC_EMITIR:CREATE",
        "actionB": "FAC_EMITIR:APPROVE",
        "description": "Quien emite una factura no puede aprobarla",
        "severity": "CRITICAL",
        "mitigation": "DENY",
        "isOverridable": false
      },
      {
        "ruleId": "SOD-FAC-CREATE-ANULAR",
        "actionA": "FAC_EMITIR:CREATE",
        "actionB": "FAC_ANULAR:EXECUTE",
        "description": "Quien emite una factura no puede anularla — requiere separación temporal mínima de 24h",
        "severity": "CRITICAL",
        "mitigation": "DENY",
        "isOverridable": true,
        "overrideRequiresRoles": ["ROL-ORG-CFO", "ROL-ORG-CCO"],
        "overrideRequiresJustification": true
      },
      {
        "ruleId": "SOD-COBRO-CONCILIAR",
        "actionA": "COBRO_RECIBIR:CREATE",
        "actionB": "COBRO_RECIBIR:RECONCILE",
        "description": "Quien recibe cobros no puede conciliarlos contra extractos bancarios",
        "severity": "CRITICAL",
        "mitigation": "DENY",
        "isOverridable": false
      },
      {
        "ruleId": "SOD-CAJA-APERTURA-CIERRE",
        "actionA": "APERTURA_CAJA:EXECUTE",
        "actionB": "CIERRE_CAJA:EXECUTE",
        "description": "Quien abre caja no puede cerrarla (auditoría de turno independiente)",
        "severity": "HIGH",
        "mitigation": "DENY",
        "isOverridable": true,
        "overrideRequiresRoles": ["ROL-ORG-GER-VENT"],
        "overrideMaxTimesPerMonth": 2
      },
      {
        "ruleId": "SOD-VENTAS-AUDITORIA",
        "actionA": "FAC_EMITIR:CREATE",
        "actionB": "AUDIT_VENTAS:EXECUTE",
        "description": "Quien crea transacciones de ventas no puede auditar el área de ventas",
        "severity": "HIGH",
        "mitigation": "DENY",
        "isOverridable": false
      }
    ],

    "transactionSchedule": {
      "type": "SCHEDULED",
      "timezone": "America/La_Paz",
      "periods": [
        {
          "name": "Ventas y Cobros — Lunes a Viernes",
          "daysOfWeek": ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY"],
          "hours": {"start": "08:30", "end": "18:00"}
        },
        {
          "name": "Sábados — Media Jornada",
          "daysOfWeek": ["SATURDAY"],
          "hours": {"start": "08:30", "end": "12:30"}
        }
      ],
      "emergencyOverride": {
        "allowed": false,
        "requiresApproval": true,
        "approverRoles": ["ROL-ORG-CFO", "ROL-ORG-CEO"],
        "maxDurationHours": 2,
        "auditLogging": "CRITICAL",
        "documentationRequired": true,
        "postOverrideReviewRequired": true,
        "maxOverridesPerMonth": 3
      }
    },

    "geospatialControl": {
      "allowedLocations": [
        {
          "type": "OFFICE",
          "name": "Sucursal física asignada",
          "networkRanges": ["10.0.1.0/24"],
          "requireSecureNetwork": true,
          "requireLocationVerification": true,
          "gpsRequired": false
        }
      ],
      "blockRemoteTransactions": true,
      "blockForeignIpTransactions": true,
      "allowedCountries": ["BO"],
      "validationRules": {
        "requireSecureNetwork": true,
        "allowRemote": false,
        "allowVpn": false,
        "requireLocationVerification": true,
        "geoVelocityCheck": true,
        "maxVelocityKmh": 500
      }
    },

    "sinCompliance": {
      "country": "BO",
      "taxAuthority": "SIN",
      "regulatoryFramework": "RND_102100000011",
      "electronicInvoicingMandatory": true,
      "offlineContingencyAllowed": true,
      "offlineMaxHours": 48,
      "offlineAutoSync": true,
      "digitalSignatureRequired": true,
      "digitalSignatureAlgorithm": "EDDSA_ED25519",
      "certificateProvider": "ADSIB",
      "certificateValidityYears": 2
    }
  }
}
```

---

# SECCIÓN 4 — `temporal_schedule` (D4 — TEMPORAL)

**Dominio:** D4 — Temporal · **Tipo:** Policy-Path

```json
{
  "temporal_schedule": {
    "scheduleType": "SPECIFIC_DAYS",
    "timezone": "America/La_Paz",
    "calendarId": "uuid-work-calendar",

    "allowedDays": [
      {"day": "MONDAY",    "shifts": [{"start": "08:00", "end": "12:00", "type": "WORK"}, {"start": "14:00", "end": "18:00", "type": "WORK"}]},
      {"day": "TUESDAY",   "shifts": [{"start": "08:00", "end": "12:00", "type": "WORK"}, {"start": "14:00", "end": "18:00", "type": "WORK"}]},
      {"day": "WEDNESDAY", "shifts": [{"start": "08:00", "end": "12:00", "type": "WORK"}, {"start": "14:00", "end": "18:00", "type": "WORK"}]},
      {"day": "THURSDAY",  "shifts": [{"start": "08:00", "end": "12:00", "type": "WORK"}, {"start": "14:00", "end": "18:00", "type": "WORK"}]},
      {"day": "FRIDAY",    "shifts": [{"start": "08:00", "end": "15:00", "type": "WORK"}]}
    ],

    "allowOvertime": false,
    "overtimePolicy": {
      "maxOvertimeHoursPerDay": 0,
      "maxOvertimeHoursPerWeek": 0,
      "overtimeApprovalRequired": true,
      "overtimeApproverRoles": ["ROL-ORG-GER-VENT", "ROL-ORG-CHRO"],
      "overtimeRateMultiplier": 1.5,
      "nightShiftRateMultiplier": 2.0,
      "holidayRateMultiplier": 2.5
    },

    "requiresApprovalOutside": true,
    "approvalOutsidePolicy": {
      "approverRoles": ["ROL-ORG-GER-VENT"],
      "maxAdvanceNoticeHours": 24,
      "emergencyAccessAllowed": true,
      "emergencyMaxDurationHours": 2,
      "auditAllOutsideAccess": true
    },

    "exceptions": {
      "holidays": "BLOCKED",
      "holidayCalendarId": "uuid-bolivia-holidays",
      "specialDates": [
        {"date": "2026-02-01", "status": "BLOCKED", "reason": "Inventario Anual Obligatorio"},
        {"date": "2026-12-24", "status": "EARLY_CLOSURE", "closureTime": "12:00", "reason": "Nochebuena"},
        {"date": "2026-12-31", "status": "EARLY_CLOSURE", "closureTime": "12:00", "reason": "Fin de Año"}
      ],
      "emergencyOverride": {
        "allowed": false,
        "requiresApproval": true,
        "approverRoles": ["ROL-ORG-DIR-IT", "ROL-SYS-ADMIN-SEGURIDAD"],
        "maxDurationHours": 4,
        "auditLogging": "COMPREHENSIVE",
        "documentationRequired": true,
        "postOverrideReviewRequired": true
      }
    },

    "sessionManagement": {
      "maxSessionDurationSeconds": 28800,
      "inactivityTimeoutSeconds": 900,
      "warningBeforeTimeoutSeconds": 120,
      "forceLogoutAtEndShift": true,
      "gracePeriodAfterShiftMinutes": 15,
      "concurrentSessionsAllowed": false,
      "maxConcurrentSessions": 1,
      "reauthenticationIntervalSeconds": 14400,
      "sessionExtensionAllowed": true,
      "sessionExtensionMaxSeconds": 3600,
      "sessionExtensionRequiresApproval": true
    },

    "breakManagement": {
      "lunchBreakRequired": true,
      "lunchBreakDurationMinutes": 60,
      "lunchBreakWindow": {"start": "12:00", "end": "14:00"},
      "shortBreaksAllowed": 2,
      "shortBreakDurationMinutes": 15,
      "autoLogoutDuringBreak": false,
      "sessionPauseDuringBreak": true
    },

    "attendanceTracking": {
      "clockInRequired": true,
      "clockInMethod": ["NFC_MIFARE_DESFIRE", "FINGERPRINT_HASH", "QR_DYNAMIC"],
      "clockOutRequired": true,
      "clockInWindowBeforeMinutes": 15,
      "clockInGraceAfterMinutes": 5,
      "lateThresholdMinutes": 15,
      "lateAction": "NOTIFY_SUPERVISOR",
      "absentAction": "ESCALATE_HR",
      "absentThresholdHours": 2,
      "autoClockOutAtEndShift": true
    }
  }
}
```

---

# SECCIÓN 5 — `biometric` (D5 — BIOMÉTRICO)

```json
{
  "biometric": {
    "types": [
      {
        "type": "FINGERPRINT",
        "standard": "ISO/IEC 19794-2:2011",
        "minutiaeFormat": "ISO/IEC 19794-2",
        "templateStorage": "HASH_ONLY",
        "sensorTypes": ["OPTICAL", "CAPACITIVE", "ULTRASONIC"],
        "minSensorResolutionDpi": 500,
        "livenessRequired": true,
        "livenessMethods": ["PASSIVE"],
        "fmrThreshold": "1:10000",
        "maxEnrollmentsPerUser": 10,
        "antiSpoofingLevel": "LEVEL_2",
        "description": "Huella dactilar — FMR ≤ 1:10,000. 500 DPI mínimo. Liveness pasiva anti-spoofing Nivel 2."
      },
      {
        "type": "FACE_3D",
        "standard": "ISO/IEC 19794-5:2018",
        "templateStorage": "HASH_ONLY",
        "sensorTypes": ["IR_DEPTH", "STRUCTURED_LIGHT", "LIDAR"],
        "livenessRequired": true,
        "livenessMethods": ["ACTIVE", "PASSIVE"],
        "activeChallenge": "RANDOM_HEAD_MOVEMENT",
        "fmrThreshold": "1:100000",
        "maxEnrollmentsPerUser": 3,
        "antiSpoofingLevel": "LEVEL_3",
        "description": "Reconocimiento facial 3D — FMR ≤ 1:100,000. Liveness activa aleatoria. Anti-spoofing Nivel 3 contra máscaras 3D y deepfakes."
      },
      {
        "type": "IRIS",
        "standard": "ISO/IEC 19794-6:2019",
        "templateStorage": "HASH_ONLY",
        "sensorTypes": ["NIR_CAMERA"],
        "livenessRequired": true,
        "livenessMethods": ["COMBINED"],
        "fmrThreshold": "1:1000000",
        "maxEnrollmentsPerUser": 2,
        "antiSpoofingLevel": "LEVEL_4",
        "description": "Iris — FMR ≤ 1:1,000,000. Liveness combinada pasiva+activa. Anti-spoofing Nivel 4. Para zonas de máxima seguridad."
      }
    ],
    "required": [],

    "livenessRequired": false,
    "livenessMethod": "PASSIVE",
    "farThreshold": 0.0001,
    "enrollmentMandatory": false,

    "enrollmentPolicy": {
      "mode": "HYBRID",
      "riskLevel": "MEDIUM",
      "hashAlgorithm": "Argon2id",
      "argon2Params": {"timeCost": 3, "memoryMb": 64, "parallelism": 2, "saltLength": 16, "hashLength": 32},
      "fmrThreshold": "1:10000",
      "maxFailedAttempts": 3,
      "supervisorRequired": true,
      "dualEnrollment": false,
      "enrollmentStations": ["PHY_ZONE_CAJA"],
      "qualityCheckRequired": true,
      "minQualityScore": 70
    },

    "alternativeNonBiometric": {
      "method": "QR_DYNAMIC",
      "maxUsesPerDay": 5,
      "requiresApproval": false,
      "auditAllUses": true,
      "description": "Alternativa obligatoria según NIST SP 800-63B-4 §5.2.3 — siempre debe existir un método no biométrico"
    },

    "gdprCompliance": {
      "requiresExplicitConsent": true,
      "consentRevocable": true,
      "consentWithdrawalEffect": "IMMEDIATE_DEACTIVATION",
      "dataRetentionDays": 365,
      "rightToDeletion": true,
      "deletionMethod": "CRYPTOGRAPHIC_ERASURE",
      "processingPurpose": "ACCESS_CONTROL",
      "legalBasis": "EXPLICIT_CONSENT",
      "dataEncryptedAtRest": true,
      "encryptionAlgorithm": "AES-256-GCM",
      "crossBorderTransfer": false,
      "dpaRequired": true,
      "breachNotificationHours": 72
    }
  }
}
```

---

# SECCIÓN 6 — `geospatial` (D6 — GEOESPACIAL)

```json
{
  "geospatial": {
    "countries": {
      "available": [
        {"isoAlpha2": "BO", "isoAlpha3": "BOL", "nameCommon": "Bolivia", "nameOfficial": "Estado Plurinacional de Bolivia", "region": "South America", "subregion": "South America", "defaultTimezone": "America/La_Paz"}
      ],
      "allowed": ["BO"],
      "blockedCountries": ["KP", "IR", "SY", "CU"],
      "blockedReason": "Sanciones internacionales y restricciones de exportación"
    },

    "locationTrustTiers": {
      "HIGH": {
        "locations": ["Oficina Central La Paz", "Sucursales autorizadas"],
        "requiresNetworkVerification": true,
        "allowedOperations": ["ALL"],
        "maxSessionDuration": 28800
      },
      "MEDIUM": {
        "locations": ["VPN Corporativa"],
        "requiresVpn": true,
        "allowedOperations": ["READ", "WRITE", "EXECUTE"],
        "restrictedOperations": ["FINANCIAL_APPROVE", "USER_MANAGEMENT"],
        "maxSessionDuration": 14400
      },
      "LOW": {
        "locations": ["Cualquier ubicación"],
        "allowedOperations": ["READ"],
        "restrictedOperations": ["WRITE", "DELETE", "APPROVE", "CONFIGURE", "EMIT", "FINANCIAL_APPROVE", "USER_MANAGEMENT", "SYSTEM_CONFIG"],
        "maxSessionDuration": 3600,
        "requiresStepUp": true
      }
    },

    "geoFences": [
      {
        "name": "Sucursal La Paz — Central",
        "center": {"lat": -16.5000, "lon": -68.1500},
        "radiusMeters": 200,
        "allowedOperations": ["ALL"],
        "timezone": "America/La_Paz",
        "address": "Av. Camacho 1234, La Paz, Bolivia"
      }
    ],

    "maxDistanceKm": 500,

    "geoVelocityCheck": {
      "enabled": true,
      "maxVelocityKmh": 900,
      "toleranceKm": 10,
      "windowMinutes": 5,
      "onViolation": "REQUIRE_STEP_UP",
      "violationCoolDownMinutes": 30,
      "maxViolationsBeforeBlock": 3
    }
  }
}
```

---

# SECCIÓN 7 — `network` (D7 — RED)

```json
{
  "network": {
    "allowedCidrs": ["10.0.1.0/24", "10.0.2.0/24"],
    "vpnRequired": false,
    "vpnConfig": {
      "provider": "WIREGUARD",
      "allowedVpnCidrs": ["10.10.0.0/16"],
      "requireAlwaysOn": false,
      "requireKillSwitch": false
    },
    "mtlsRequired": false,

    "deviceTrust": {
      "minScore": 70,
      "requiredSignals": {
        "osPatched":           {"weight": 25, "maxAgeDays": 30, "mandatory": false},
        "encryptionEnabled":   {"weight": 25, "maxAgeDays": 1,  "mandatory": true},
        "firewallEnabled":     {"weight": 15, "maxAgeDays": 1,  "mandatory": true},
        "screenLockEnabled":   {"weight": 10, "maxAgeDays": 1,  "mandatory": true},
        "antivirusRunning":    {"weight": 15, "maxAgeDays": 1,  "mandatory": false},
        "noRootJailbreak":     {"weight": 10, "maxAgeDays": 1,  "mandatory": true}
      },
      "onScoreBelowMinimum": "BLOCK_ACCESS",
      "gracePeriodForRemediation": 3600,
      "remediationMessage": "Su dispositivo no cumple con los requisitos de seguridad. Por favor actualice su sistema y reintente en 1 hora."
    },

    "continuousVerification": {
      "enabled": true,
      "intervalSeconds": 300,
      "signalSources": ["MDM", "EDR", "SIEM"],
      "onFailure": "REVOKE_SESSION",
      "gracePeriodSeconds": 60
    },

    "networkSegmentation": {
      "allowedVlans": [10, 20],
      "allowedZones": ["CORPORATE"],
      "blockedZones": ["DMZ", "MANAGEMENT", "IOT", "GUEST_WIFI"],
      "requireIdsIps": false
    },

    "sessionBinding": {
      "bindToDevice": true,
      "bindToNetwork": false,
      "bindToLocation": false,
      "requireDpop": false,
      "tokenType": "Bearer"
    },

    "allowedProtocols": ["HTTPS", "WSS"],
    "blockedPorts": [22, 23, 3389, 5900, 27017, 6379, 5432],

    "ztnaPolicy": {
      "defaultAction": "DENY",
      "allowedServices": ["tryton", "keycloak", "superset", "espocrm"],
      "microsegmentation": false,
      "requireJustInTime": false
    }
  }
}
```

---

# SECCIÓN 8 — `session_context` (D8 — CONTEXTO)

```json
{
  "session_context": {
    "ctxIdScope": "COMPANY",

    "ctxIdCompliance": {
      "version": "1.0",
      "fields": ["tenant_id", "empresa_id", "sucursal_id", "pos_logico", "user_id"],
      "w3cTraceparent": true,
      "otelBaggage": true,
      "customFields": ["role_id", "session_id"]
    },

    "sessionTtlMax": 28800,
    "inactivityTimeoutSeconds": 900,
    "reauthTimeout": 900,
    "maxConcurrentSessions": 1,

    "sessionRisk": {
      "evaluation": "REAL_TIME",
      "riskFactors": [
        "geo_velocity",
        "device_change",
        "time_anomaly",
        "behavior_anomaly",
        "network_change",
        "failed_auth_spike"
      ],
      "highRiskAction": "REQUIRE_STEP_UP",
      "criticalRiskAction": "TERMINATE_SESSION",
      "riskScoreThreshold": {"low": 30, "medium": 60, "high": 80, "critical": 95}
    },

    "contextSwitching": {
      "allowed": false,
      "maxContexts": 1,
      "allowedSwitchTo": [],
      "requiresApproval": true,
      "auditAllSwitches": true,
      "cooldownSeconds": 60
    },

    "caepEvents": [
      "session-revoked",
      "token-claims-change",
      "assurance-level-change",
      "credential-change"
    ],

    "forceLogoutOn": [
      "END_SHIFT",
      "HOLIDAY",
      "DEVICE_COMPROMISE",
      "CRITICAL_RISK_DETECTED",
      "PASSWORD_CHANGE",
      "ROLE_REVOKED"
    ]
  }
}
```

---

# SECCIÓN 9 — `credential_policy` (D9 — CREDENCIALES)

```json
{
  "credential_policy": {
    "minAal": "AAL2",
    "mfaRequired": true,
    "sessionTimeoutSecs": 28800,

    "phishingResistance": {
      "required": true,
      "allowedMethods": ["WEBAUTHN_PWDLESS", "PASSKEY_DEVICE", "SMARTCARD_X509"],
      "syncablePasskeys": {"allowed": true, "maxAal": "AAL2"},
      "deviceBoundKeys": {"requiredForAal3": true}
    },

    "passwordPolicy": {
      "minLength": 12,
      "noComplexityRules": true,
      "noPeriodicRotation": true,
      "hibpCheck": true,
      "blocklist": ["password", "12345678", "123456789", "qwerty123", "admin", "skull", "sbos", "bolivia123", "lapaz123"],
      "maxAgeDays": null,
      "historyCheckCount": 5,
      "hashAlgorithm": "Argon2id",
      "argon2Params": {"timeCost": 3, "memoryMb": 64, "parallelism": 2, "saltLength": 16, "hashLength": 32}
    },

    "recoveryPolicy": {
      "methods": ["EMAIL_OTP", "BACKUP_CODES", "ADMIN_RESET"],
      "requiresMfa": true,
      "rateLimit": {"maxAttempts": 3, "windowSeconds": 3600},
      "notificationChannels": ["EMAIL", "PUSH", "ROCKET_CHAT"],
      "coolDownPeriodHours": 24,
      "mandatoryBackupCodesCount": 10,
      "backupCodesSingleUse": true
    },

    "lockoutPolicy": {
      "type": "PROGRESSIVE",
      "levels": [
        {"attempts": 3,  "durationSeconds": 900,  "notifyUser": true,  "action": "CAPTCHA"},
        {"attempts": 5,  "durationSeconds": 3600, "notifyUser": true,  "action": "MFA_CHALLENGE", "notifySecurity": true},
        {"attempts": 10, "durationSeconds": 86400,"notifyUser": true,  "action": "ACCOUNT_FROZEN", "notifySecurity": true, "notifySupervisor": true}
      ],
      "mitigation": ["CAPTCHA", "MFA_CHALLENGE", "EMAIL_VERIFICATION"],
      "permanentLockThreshold": 50,
      "permanentLockAction": "REQUIRE_ADMIN_RESET"
    },

    "credentialRotation": {
      "enabled": true,
      "rotationDays": 90,
      "notifyBeforeDays": 14,
      "autoRotateServiceAccounts": true,
      "revokeOnRotation": true,
      "forceRotationOnCompromise": true
    },

    "appliedPolicies": [
      {"policyId": "PWD_HIBP_CHECK",     "policyName": "Verificación HIBP",     "standard": "NIST SP 800-63B-4 Final", "enforcement": "HARD"},
      {"policyId": "PWD_NO_ROTATION",    "policyName": "Sin Rotación Forzada",  "standard": "NIST SP 800-63B-4 Final", "enforcement": "HARD"},
      {"policyId": "MFA_AAL2_REQUIRED",  "policyName": "MFA Obligatorio AAL2",  "standard": "NIST SP 800-63B-4 AAL2",  "enforcement": "HARD"},
      {"policyId": "PR_PHISH_FIDO2",     "policyName": "Phishing-Resistant AAL2+","standard": "NIST SP 800-63B-4 Final", "enforcement": "HARD"},
      {"policyId": "LOCKOUT_PROGRESSIVE","policyName": "Bloqueo Progresivo",     "standard": "NIST SP 800-53 AC-7",     "enforcement": "HARD"},
      {"policyId": "RECOVERY_MFA",       "policyName": "Recuperación con MFA",   "standard": "OWASP ASVS V2.5.1",        "enforcement": "HARD"},
      {"policyId": "SESSION_TIMEOUT_8H",  "policyName": "Timeout de Sesión 8h", "standard": "NIST SP 800-63B-4 §7",    "enforcement": "SOFT"}
    ]
  }
}
```

---

# SECCIÓN 10 — `delegation` (D10 — DELEGACIÓN)

```json
{
  "delegation": {
    "canDelegate": true,
    "allowedTargetRoles": ["ROL-ORG-VEND-JUNIOR", "ROL-ORG-VEND-SENIOR"],
    "maxDurationHours": 168,
    "requiresApproval": true,
    "approverRoles": ["ROL-ORG-GER-VENT"],
    "autoRevoke": true,
    "maxConcurrentDelegations": 1,

    "nonDelegablePermissions": [
      "system_config_change",
      "user_role_assignment",
      "financial_approve_above_50000",
      "audit_log_delete",
      "digital_signature_create"
    ],

    "delegationChain": {
      "allowRedelegation": false,
      "maxChainDepth": 1,
      "originalDelegatorRetainsResponsibility": true
    },

    "notificationChannels": ["email", "rocket_chat"],

    "auditRequirements": {
      "logDelegationCreation": true,
      "logDelegationUse": true,
      "logDelegationRevocation": true,
      "retentionDays": 2555
    }
  }
}
```

---

# SECCIÓN 11 — `audit` (D11 — AUDITORÍA)

```json
{
  "audit": {
    "level": "basic",
    "retentionDays": 2555,
    "hashChainRequired": false,

    "eventsToLog": [
      "ACCESS", "AUTH", "AUTH_FAILURE", "FINANCIAL",
      "ROLE_CHANGE", "PERMISSION_CHANGE", "DELEGATION",
      "CONFIG_CHANGE", "DATA_EXPORT", "PRIVILEGED_OPERATION"
    ],

    "reviewFrequency": "QUARTERLY",
    "lastReviewDate": null,
    "nextReviewDate": null,
    "autoRevokeOnReviewFailure": false,
    "slaDays": 14,
    "escalation": ["ROL-SYS-ADMIN-SEGURIDAD", "ROL-ORG-CHRO"],
    "reviewers": ["ROL-ORG-GER-VENT", "ROL-ORG-DIR-FIN"],

    "regulatoryFrameworks": {
      "pciDss": {"applicable": false},
      "sox": {"applicable": false},
      "gdpr": {"applicable": true, "piiAccess": false, "legalBasis": "LEGITIMATE_INTEREST", "dataMinimization": true, "retentionDays": 365},
      "iso27001": {"applicable": true, "controls": ["A.5.15", "A.5.16", "A.5.17", "A.5.18", "A.8.2", "A.8.5", "A.8.15"]}
    },

    "changeTracking": {
      "trackedElements": ["PERMISSIONS", "AUTHENTICATION_METHODS", "TEMPORAL_ACCESS", "DELEGATIONS", "FINANCIAL_LIMITS", "SOD_RULES"],
      "retentionYears": 7,
      "hashChainRequired": false,
      "tamperProof": "SHA-256"
    }
  }
}
```

---

# SECCIÓN 12 — `blockchain` (D12 — BLOCKCHAIN)

```json
{
  "blockchain": {
    "merkleAnchoringRequired": false,
    "anchorFrequency": "batch",

    "didIdentity": {
      "enabled": false,
      "didMethod": null,
      "didDocument": null,
      "verificationMethods": [],
      "alsoKnownAs": []
    },

    "proofTypes": {
      "supported": ["MERKLE_PROOF"],
      "preferred": null,
      "verificationGasLimit": 300000
    },

    "smartContract": {
      "address": null,
      "chainId": null,
      "abiReference": null,
      "events": ["RoleAssigned", "RoleRevoked", "AnchorCreated"],
      "ownerAddress": null
    },

    "besuQbftEnabled": false,
    "besuConfig": {
      "network": null,
      "nodeUrl": null,
      "consensus": "QBFT",
      "blockTimeSeconds": 2,
      "gasLimit": 10000000
    }
  }
}
```

---

# SECCIÓN 13 — `sync_metadata` — SINCRONIZACIÓN KC + TRYTON

```json
{
  "sync_metadata": {
    "_readonly": true,
    "_description": "Gestionado exclusivamente por bAuth.PrivilegeEngine. No editar manualmente.",
    "syncStatus": "PENDING",
    "lastSyncAt": null,
    "errorMessage": null,

    "syncTargets": {
      "keycloak": {
        "target": "kc_realm_role",
        "status": "NOT_SYNCED",
        "compositeRole": "ROL-ORG-CAJ",
        "authFlowBrowser": "sbos-webauthn-2fa",
        "authFlowDirectGrant": null,
        "userAttributes": [
          "logical_access_zones",
          "logical_access_scope",
          "data_classification_level",
          "step_up_rules",
          "session_timeout_secs",
          "allowed_cidrs"
        ],
        "mfaRequired": true,
        "aal": "AAL2",
        "lastSyncAt": null
      },
      "tryton": {
        "target": "tryton_group",
        "status": "NOT_SYNCED",
        "groupName": "ROL-ORG-CAJ",
        "parentGroup": "ROL-ORG-GER-VENT",
        "irModelAccess": null,
        "irRules": null,
        "irButtonRules": null,
        "irActionGroups": null,
        "lastSyncAt": null
      }
    },

    "driftDetection": {
      "enabled": true,
      "checkIntervalSeconds": 60,
      "autoReconcile": true,
      "maxDriftToleranceSeconds": 300,
      "onDriftDetected": "AUTO_RECONCILE",
      "onReconcileFailure": "ALERT_HITL"
    }
  }
}
```

---

# SECCIÓN 14 — `conflict_management` — SoD Y CONFLICTOS

```json
{
  "conflict_management": {
    "segregationOfDuties": {
      "incompatibleRoles": [
        {
          "incompatibleWith": "ROL-ORG-AUDITOR-INTERNO",
          "description": "Un operador de caja no puede ser auditor interno simultáneamente",
          "severity": "CRITICAL",
          "mitigation": "DENY"
        },
        {
          "incompatibleWith": "ROL-SYS-ADMIN-BAUTH",
          "description": "Un operador no puede administrar el sistema de identidad",
          "severity": "CRITICAL",
          "mitigation": "DENY"
        }
      ],
      "incompatibleFunctions": [
        {
          "functionA": "FAC_EMITIR:CREATE",
          "functionB": "FAC_EMITIR:APPROVE",
          "description": "Quien emite facturas no puede aprobarlas",
          "severity": "CRITICAL",
          "mitigation": "DENY"
        }
      ],
      "conflictValidation": {
        "checkFrequency": "REAL_TIME",
        "validationScope": ["DIRECT_CONFLICTS", "INHERITED_CONFLICTS", "DELEGATION_CONFLICTS"]
      }
    },
    "interestConflicts": {
      "restrictedEntities": [
        {
          "type": "VENDORS",
          "validationRules": {
            "checkOwnership": true,
            "checkRelationship": true,
            "relationshipDegrees": 2
          }
        }
      ],
      "declarationRequirements": {
        "frequency": "ANNUAL",
        "requiresUpdateOnChange": true,
        "verificationMethod": "COMPLIANCE_REVIEW",
        "documentation": "mandatory"
      }
    }
  }
}
```

---

*Documento generado 2026-06-24. Secciones D2-D14 con ~600 atributos nuevos.*
*Debe consolidarse con BAUTH-ROLTEMPLATE-SECCIONES.md sección D1.*
