# SBOS — UserTemplate: Contrato Definitivo v5.0
## La Identidad Digital Completa de un Actor en el SBOS
### SKULL · SBOS — Sovereign Business Operating System
### v5.0 · Abril 2026

---

| Campo | Valor |
|---|---|
| **Código** | SBOS-USERTEMPLATE-v5_0 |
| **Versión** | 5.0 — definitiva, reemplaza EstructuraUserFinal.txt y §4 de SBOS-BAUTH-CONCEPTUALIZACION-v4_0 |
| **Estado** | ACTIVO |
| **Propósito** | Especificación JSONB completa del UserTemplate — contrato de identidad de un actor individual |
| **Almacenamiento** | PostgreSQL tabla `bos_user_template`, columna `template JSONB` |
| **Estándares** | NIST SP 800-63B/C · ISO/IEC 24760 · SCIM 2.0 (RFC 7643/7644) · OIDC Core 1.0 · RGPD Art.4/9/17 · ISO/IEC 27701 · FIDO2/WebAuthn W3C |
| **Integra** | Authentication_Framework.json · Policies_Authentication_Framework.json · SBOS-BAUTH-CONCEPTUALIZACION-v4_0 · SBOS-ROLTEMPLATE-v5_0 |

---

## PRINCIPIO ABSOLUTO

> **El UserTemplate es el contrato que define QUIÉN ES y QUÉ TIENE este usuario concreto.**
> Los permisos NO viven aquí — viven en el RolTemplate asignado.
> El UserTemplate define la identidad; el RolTemplate define la autoridad.

**Pregunta del UserTemplate:** ¿Quién ES este usuario y qué credenciales TIENE registradas?
**Granularidad:** Define un individuo concreto.
**Multiplicidad:** Un UserTemplate → un único usuario.

---

## SEPARACIÓN CRÍTICA: USERTEMPLATE vs ROLTEMPLATE

| Dimensión | UserTemplate | RolTemplate |
|---|---|---|
| **Pregunta** | ¿QUIÉN es este usuario? | ¿QUÉ puede hacer este tipo de rol? |
| **Permisos** | Hereda del RolTemplate asignado | Define los permisos |
| **Autenticación** | Registra qué métodos TIENE disponibles | Define qué métodos son REQUERIDOS |
| **Horario** | Puede tener excepciones individuales | Define el horario base del rol |
| **Biometría** | Almacena el hash biométrico del individuo | Define la política de enrollment |
| **Sincroniza en KC** | User record, credenciales, atributos individuales | Auth Flows, Session Settings, User Attributes del rol |
| **Sincroniza en Tryton** | `res.user`, `company.employee`, empresa activa | Grupos, `ir.model.access`, Button Rules |

---

## ESTRUCTURA JSONB COMPLETA

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

---

## FLUJO DE ONBOARDING (Ciclo de Vida del UserTemplate)

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

## REGLAS DE VALIDACIÓN

### Validaciones de Schema

| Campo | Regla | Error |
|---|---|---|
| `uuid` | UUID v4 válido y único | `DUPLICATE_UUID` |
| `username` | Único por tenant, regex `^[a-z][a-z0-9._-]{2,64}$` | `INVALID_USERNAME` |
| `account_type` | HUMAN\|SERVICE\|SYSTEM\|GUEST | `INVALID_ACCOUNT_TYPE` |
| `roles_assignments.active_roles[].role_id` | Debe existir en `bos_rol_template` con status ACTIVE | `ROLE_NOT_FOUND` |
| `keycloak_credentials.has_totp OR has_webauthn` | Al menos 1 factor MFA cuando role requiere LoA >= 2 | `MFA_NOT_CONFIGURED` |
| `compliance_control.certifications_status[blocking=true]` | Todos con status=CURRENT para account_type=HUMAN | `BLOCKING_CERT_MISSING` |

### Validaciones Semánticas

| Regla | Descripción |
|---|---|
| **Credential coverage** | `credentials_compliance.covers_required_methods = true` antes de ACTIVE |
| **Biometric consent** | Si hay biometric_templates → consent_given debe ser true |
| **SoD check** | Roles en active_roles no deben violar SoD del tenant |
| **Delegation valid** | temporary_assignments verificados contra delegation_config del RolTemplate fuente |

---

## CAMPOS PII Y ENMASCARAMIENTO

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

## INVARIANTES DE SEGURIDAD

1. **Raw biometric NUNCA en el UserTemplate** — solo hashes PBKDF2-SHA256
2. **Contraseña NUNCA en el UserTemplate** — vive solo en Keycloak (bcrypt)
3. **UUID INMUTABLE** — nunca cambia aunque el usuario cambie de rol o empresa
4. **Permisos NUNCA en el UserTemplate** — siempre heredados del RolTemplate
5. **Un solo rol activo por defecto** — múltiples roles requieren aprobación ARB
6. **Consentimiento biométrico EXPLÍCITO** — campo boolean + fecha

---

*SKULL · SBOS · SBOS-USERTEMPLATE-v5_0 · Abril 2026*
*Reemplaza: EstructuraUserFinal.txt + §4 SBOS-BAUTH-CONCEPTUALIZACION-v4_0*
*Estándares: NIST SP 800-63B · ISO/IEC 24760 · SCIM 2.0 RFC 7643 · OIDC Core 1.0 · RGPD Art.4/9/17 · ISO/IEC 27701 · FIDO2/WebAuthn W3C · SIA OSDP v2.2.2*
